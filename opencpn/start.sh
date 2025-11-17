#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

# Display & desktop sizing
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# Serve on this port. Both HTTP and HTTPS can work here (ssl.require_ssl=false).
# Env precedence: KASMVNC_PORT > NOVNC_PORT > options.json > 6080
KASMVNC_PORT_ENV="${KASMVNC_PORT:-${NOVNC_PORT:-}}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

jq_get() {
  local key="$1" default="${2:-}"
  if [[ -f "$CONFIG_PATH" ]]; then
    local val
    val="$(jq -r "$key // empty" "$CONFIG_PATH" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "$default"
}

log "[INFO] Starting OpenCPN Home Assistant add-on"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

# ---------- Read configuration ----------
# Password from env or options.json
VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"

# INSECURE_MODE: env overrides JSON; default false
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

# KasmVNC port: env override > JSON > fallback 6080
KASMVNC_PORT_CFG="$(jq_get '.kasmvnc_port' '0')"
if [[ -n "${KASMVNC_PORT_ENV:-}" ]]; then
  KASMVNC_PORT="$KASMVNC_PORT_ENV"
elif [[ "$KASMVNC_PORT_CFG" != "0" && -n "$KASMVNC_PORT_CFG" ]]; then
  KASMVNC_PORT="$KASMVNC_PORT_CFG"
else
  KASMVNC_PORT="6080"
fi

# ---------- Sanity checks ----------
command -v vncserver     >/dev/null 2>&1 || { log "[ERROR] 'vncserver' (KasmVNC) not found"; exit 1; }
command -v kasmvncpasswd >/dev/null 2>&1 || { log "[ERROR] 'kasmvncpasswd' not found"; exit 1; }
command -v jq            >/dev/null 2>&1 || log "[WARN] 'jq' not found; options.json parsing may be limited."
command -v curl          >/dev/null 2>&1 || log "[WARN] 'curl' not found; HTTP health checks will be skipped."

# ---------- Password handling ----------
# If insecure_mode=true and no password provided, use weak default
if [[ "$INSECURE_MODE" == "true" && -z "${VNC_PASSWORD:-}" ]]; then
  VNC_PASSWORD="opencpn"
  log "[WARN] insecure_mode=true and no password provided; using default 'opencpn' (INSECURE)"
fi

# If still empty: error out (safer than hidden default)
if [[ -z "${VNC_PASSWORD:-}" ]]; then
  log "[ERROR] No VNC password set. Provide 'vnc_password' in options.json or set INSECURE_MODE=true."
  exit 1
fi

MASKED=""; [[ -n "${VNC_PASSWORD:-}" ]] && MASKED="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED}'"
log "[DEBUG] kasmvnc_port='${KASMVNC_PORT}' (HTTP and HTTPS)"

# ---------- DBus ----------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ---------- KasmVNC auth ----------
log "[INFO] Setting KasmVNC password for user 'root'..."
mkdir -p /root
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root -w /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# ---------- OpenCPN autostart in XFCE ----------
log "[INFO] Configuring XFCE autostart for OpenCPN..."
mkdir -p /root/.config/autostart
cat >/root/.config/autostart/opencpn.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=OpenCPN
Exec=opencpn
X-GNOME-Autostart-enabled=true
EOF

# ---------- KasmVNC YAML config ----------
log "[INFO] Writing KasmVNC YAML config..."
mkdir -p /etc/kasmvnc /root/.vnc

cat >/etc/kasmvnc/kasmvnc.yaml <<EOF
desktop:
  resolution:
    width: ${VNC_RESOLUTION%x*}
    height: ${VNC_RESOLUTION#*x}
  allow_resize: true
  pixel_depth: 24

network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: ${KASMVNC_PORT}
  use_ipv4: true
  use_ipv6: false
  udp:
    public_ip: auto
    port: auto
    stun_server: auto
  ssl:
    require_ssl: false

user_session:
  new_session_disconnects_existing_exclusive_session: false
  concurrent_connections_prompt: false
  concurrent_connections_prompt_timeout: 10
  idle_timeout: never

keyboard:
  remap_keys:
  ignore_numlock: false
  raw_keyboard: false

pointer:
  enabled: true

runtime_configuration:
  allow_client_to_override_kasm_server_settings: true
  allow_override_standard_vnc_server_settings: true
  allow_override_list:
    - pointer.enabled
    - data_loss_prevention.clipboard.server_to_client.enabled
    - data_loss_prevention.clipboard.client_to_server.enabled
    - data_loss_prevention.clipboard.server_to_client.primary_clipboard_enabled

logging:
  log_writer_name: all
  log_dest: logfile
  level: 30

data_loss_prevention:
  visible_region:
    concealed_region:
      allow_click_down: false
      allow_click_release: false
  clipboard:
    delay_between_operations: none
    allow_mimetypes:
      - chromium/x-web-custom-data
      - text/html
      - image/png
    server_to_client:
      enabled: true
      size: unlimited
      primary_clipboard_enabled: false
    client_to_server:
      enabled: true
      size: unlimited
  keyboard:
    enabled: true
    rate_limit: unlimited
  logging:
    level: off

encoding:
  max_frame_rate: 60
  full_frame_updates: none
  rect_encoding_mode:
    min_quality: 7
    max_quality: 8
    consider_lossless_quality: 10
    rectangle_compress_threads: auto

  video_encoding_mode:
    jpeg_quality: -1
    webp_quality: -1
    max_resolution:
      width: 1920
      height: 1080
    enter_video_encoding_mode:
      time_threshold: 5
      area_threshold: 45%
    exit_video_encoding_mode:
      time_threshold: 3
    logging:
      level: off
    scaling_algorithm: progressive_bilinear

  compare_framebuffer: auto
  zrle_zlib_level: auto
  hextile_improved_compression: true

server:
  http:
    headers:
      - Cross-Origin-Embedder-Policy=require-corp
      - Cross-Origin-Opener-Policy=same-origin
    httpd_directory: /usr/share/kasmvnc/www
  advanced:
    x_font_path: auto
    kasm_password_file: /root/.kasmpasswd
    x_authority_file: auto
  auto_shutdown:
    no_user_session_timeout: never
    active_user_session_timeout: never
    inactive_user_session_timeout: never

command_line:
  prompt: false
EOF

# Some builds read ~/.vnc/kasmvnc.yaml instead of /etc/kasmvnc
cp /etc/kasmvnc/kasmvnc.yaml /root/.vnc/kasmvnc.yaml
chmod 600 /etc/kasmvnc/kasmvnc.yaml || true

# ---------- Start KasmVNC (vncserver wrapper, non-interactive DE) ----------
log "[INFO] Starting KasmVNC (vncserver) on display '${DISPLAY}' (HTTP :${KASMVNC_PORT}, BasicAuth DISABLED)..."

# Best-effort cleanup, but do NOT block indefinitely if it hangs
if command -v timeout >/dev/null 2>&1; then
  timeout 3 vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
else
  vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
fi

# Start a session with XFCE as desktop environment, non-interactively.
# /etc/kasmvnc/kasmvnc.yaml is picked up automatically for network/port config.
# -disableBasicAuth disables HTTP BasicAuth, ideal for HA iframe usage.
vncserver "${DISPLAY}" \
  -select-de xfce \
  -geometry "${VNC_RESOLUTION}" \
  -disableBasicAuth \
  >/var/log/kasmvncserver.log 2>&1 &

# ---------- Verify listeners (up to 30s) ----------
ok_http=false
ok_https=false

if command -v curl >/dev/null 2>&1; then
  for i in {1..30}; do
    curl -sI "http://127.0.0.1:${KASMVNC_PORT}/" >/dev/null 2>&1 && ok_http=true || true
    curl -skI "https://127.0.0.1:${KASMVNC_PORT}/" >/dev/null 2>&1 && ok_https=true || true
    if $ok_http || $ok_https; then break; fi
    sleep 1
  done
  $ok_http  && log "[INFO] HTTP listening at  http://127.0.0.1:${KASMVNC_PORT}/"
  $ok_https && log "[INFO] HTTPS listening at https://127.0.0.1:${KASMVNC_PORT}/"
else
  log "[WARN] curl not available; skipping HTTP/HTTPS health checks."
fi

if ! $ok_http && ! $ok_https; then
  log "[WARN] KasmVNC did not respond on port ${KASMVNC_PORT} within timeout; continuing anyway."
  (ss -ltnp 2>/dev/null || netstat -tlnp 2>/dev/null || true) | awk 'NR==1 || /vnc|kasm/' || true
fi

# ---------- Ready ----------
log "[INFO] Ready. Open your browser (or HA iframe) to: http://[HOST]:${KASMVNC_PORT}/"
log "[INFO] HTTP BasicAuth is DISABLED; access is controlled by your network/HA only."

# ---------- Keep container alive ----------
shopt -s nullglob
LOGS=(/var/log/kasmvncserver.log /root/.vnc/*.log)
if (( ${#LOGS[@]} > 0 )); then
  log "[INFO] Tailing logs: ${LOGS[*]}"
  tail -F "${LOGS[@]}"
else
  log "[WARN] No log files found to tail; sleeping forever."
  sleep infinity
fi
