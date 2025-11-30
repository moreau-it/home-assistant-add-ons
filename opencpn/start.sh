#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# External port seen by HA ingress (must match ingress_port in config.yaml)
EXTERNAL_PORT=6080
# Internal port where KasmVNC will actually listen
INTERNAL_PORT=6901

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
VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

# ---------- Password handling ----------
if [[ -z "${VNC_PASSWORD:-}" ]]; then
  if [[ "$INSECURE_MODE" == "true" ]]; then
    VNC_PASSWORD="opencpn"
    log "[WARN] insecure_mode=true and no vnc_password set; using default 'opencpn'"
  else
    log "[ERROR] No VNC password set. Set 'vnc_password' in options.json or enable insecure_mode."
    exit 1
  fi
fi

MASKED="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED}'"
log "[DEBUG] internal_port='${INTERNAL_PORT}', external_port='${EXTERNAL_PORT}'"

# ---------- DBus ----------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ---------- KasmVNC auth (VNC user) ----------
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
  visible_region:
    concealed_region:
      allow_click_down: false
      allow_click_release: false
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
log "[INFO] Starting KasmVNC (vncserver) on display '${DISPLAY}' (HTTP :${INTERNAL_PORT}, HTTP BasicAuth DISABLED, VNC password enabled)..."

# Best-effort cleanup, but do NOT block indefinitely if it hangs
if command -v timeout >/dev/null 2>&1; then
  timeout 3 vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
else
  vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
fi

vncserver "${DISPLAY}" \
  -select-de xfce \
  -geometry "${VNC_RESOLUTION}" \
  --disableBasicAuth \
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

# ---------- nginx as simple reverse proxy ----------
log "[INFO] Writing nginx config..."

cat >/etc/nginx/nginx.conf <<EOF
events {}

http {
  server {
    listen ${EXTERNAL_PORT};

    location / {
      # When HA ingress hits "/", send it to the Kasm UI page.
      rewrite ^/\$ /vnc.html break;

      proxy_pass http://127.0.0.1:${INTERNAL_PORT};
      proxy_http_version 1.1;

      # Make Kasm think everything is coming from localhost,
      # just like our working curl tests.
      proxy_set_header Host 127.0.0.1;
      proxy_set_header X-Real-IP 127.0.0.1;
      proxy_set_header X-Forwarded-For 127.0.0.1;

      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
    }
  }
}
EOF

log "[INFO] Starting nginx proxy on :${EXTERNAL_PORT}..."
nginx -g 'daemon off;' >/var/log/nginx.log 2>&1 &

# Final health check on nginx (external port)
if command -v curl >/dev/null 2>&1; then
  for i in {1..30}; do
    if curl -sI "http://127.0.0.1:${EXTERNAL_PORT}/" >/dev/null 2>&1; then
      log "[INFO] nginx is listening at http://127.0.0.1:${EXTERNAL_PORT}/"
      break
    fi
    sleep 1
  done
fi

log "[INFO] Ready. Use HA ingress (port ${EXTERNAL_PORT}) or http://[HOST]:${EXTERNAL_PORT}/"

# ---------- Keep container alive ----------
shopt -s nullglob
LOGS=(/var/log/kasmvncserver.log /root/.vnc/*.log /var/log/nginx.log)
if (( ${#LOGS[@]} > 0 )); then
  log "[INFO] Tailing logs: ${LOGS[*]}"
  tail -F "${LOGS[@]}"
else
  log "[WARN] No log files found to tail; sleeping forever."
  sleep infinity
fi
