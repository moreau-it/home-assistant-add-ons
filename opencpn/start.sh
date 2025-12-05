#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# KasmVNC HTTP/Websocket port inside the container
INTERNAL_PORT=6080

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

log "[INFO] Starting OpenCPN Home Assistant add-on (FULL KIOSK MODE, no HTTP BasicAuth)"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

# ---------- Read configuration ----------
VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"

# ---------- Password handling ----------
if [[ -z "${VNC_PASSWORD:-}" ]]; then
  # We still keep a VNC password (HTML login page) for safety,
  # but HTTP BasicAuth is disabled so there is no 401 pop-up.
  VNC_PASSWORD="opencpn"
  log "[WARN] No vnc_password set; using default 'opencpn'"
fi

MASKED="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] vnc_password='${MASKED}'"
log "[DEBUG] internal_port='${INTERNAL_PORT}'"

# ---------- DBus ----------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ---------- KasmVNC auth (VNC password for user root) ----------
log "[INFO] Setting KasmVNC password for user 'root'..."
mkdir -p /root
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root -w /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# ---------- Kiosk xstartup (NO DESKTOP, ONLY OPENCPN) ----------
log "[INFO] Configuring KasmVNC xstartup for OpenCPN kiosk..."
mkdir -p /root/.vnc

cat >/root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Simple solid background
xsetroot -solid black

# Hide cursor when idle, if available
if command -v unclutter >/dev/null 2>&1; then
  unclutter -idle 0.1 -root &
fi

# Hard kiosk: keep restarting OpenCPN if it exits
while true; do
  opencpn --fullscreen
  sleep 1
done
EOF

chmod +x /root/.vnc/xstartup

# ---------- KasmVNC YAML config ----------
log "[INFO] Writing KasmVNC YAML config..."
mkdir -p /etc/kasmvnc

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
  websocket_port: ${INTERNAL_PORT}
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
    - data_loss_prevention.clipboard.client_to_server.size
    - data_loss_prevention.clipboard.server_to_client.size
    
logging:
  log_writer_name: all
  log_dest: logfile
  level: 30

data_loss_prevention:
  # Keep everything interactive; DO NOT block clicks/keyboard.
  clipboard:
    delay_between_operations: none
    allow_mimetypes:
      - text/plain
      - text/html
      - image/png
      - chromium/x-web-custom-data
    server_to_client:
      enabled: true
      size: unlimited
      primary_clipboard_enabled: true
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

cp /etc/kasmvnc/kasmvnc.yaml /root/.vnc/kasmvnc.yaml
chmod 600 /etc/kasmvnc/kasmvnc.yaml || true

# ---------- Start KasmVNC ----------
log "[INFO] Starting KasmVNC (vncserver) on display '${DISPLAY}' (HTTP :${INTERNAL_PORT}, HTTP BasicAuth DISABLED, kiosk)..."

# Best-effort cleanup, but do NOT block indefinitely if it hangs
if command -v timeout >/dev/null 2>&1; then
  timeout 3 vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
else
  vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
fi

vncserver "${DISPLAY}" \
  -geometry "${VNC_RESOLUTION}" \
  -disableBasicAuth \
  >/var/log/kasmvncserver.log 2>&1 &

# Wait for KasmVNC to listen on INTERNAL_PORT
if command -v curl >/dev/null 2>&1; then
  for i in {1..30}; do
    if curl -sI "http://127.0.0.1:${INTERNAL_PORT}/" >/dev/null 2>&1; then
      log "[INFO] KasmVNC is listening on http://127.0.0.1:${INTERNAL_PORT}/"
      break
    fi
    sleep 1
  done
fi

log "[INFO] Ready. Point Cloudflare / browser at port ${INTERNAL_PORT} on the host."

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
