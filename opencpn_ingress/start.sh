#!/bin/bash
set -Eeuo pipefail

export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# KasmVNC HTTP/WebSocket inside the container
INTERNAL_PORT=6901
# nginx port exposed to Home Assistant ingress
NGINX_PORT=8099

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

log "[INFO] Starting OpenCPN (INGRESS MODE with nginx + KasmVNC)"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

# ---------- Read configuration ----------
VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:upper:]')"  # TRUE/FALSE

# ---------- Sanity checks ----------
command -v vncserver     >/dev/null 2>&1 || { log "[ERROR] 'vncserver' (KasmVNC) not found"; exit 1; }
command -v kasmvncpasswd >/dev/null 2>&1 || { log "[ERROR] 'kasmvncpasswd' not found"; exit 1; }
command -v jq            >/dev/null 2>&1 || log "[WARN] 'jq' not found; options.json parsing may be limited."
command -v curl          >/dev/null 2>&1 || log "[WARN] 'curl' not found; HTTP health checks will be skipped."
command -v nginx         >/dev/null 2>&1 || { log "[ERROR] 'nginx' not found in image"; exit 1; }

# ---------- Password handling ----------
if [[ -z "${VNC_PASSWORD:-}" ]]; then
  if [[ "$INSECURE_MODE" == "TRUE" ]]; then
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
log "[DEBUG] internal_port='${INTERNAL_PORT}', nginx_port='${NGINX_PORT}'"

# ---------- DBus ----------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ---------- KasmVNC auth (root, HTTP Basic) ----------
log "[INFO] Setting KasmVNC password for user 'root'..."
mkdir -p /root
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root -w /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# Base64 for "root:<password>" – used by nginx when talking to KasmVNC
if command -v base64 >/dev/null 2>&1; then
  KASMVNC_B64_AUTH="$(printf 'root:%s' "$VNC_PASSWORD" | base64 -w0 2>/dev/null || printf 'root:%s' "$VNC_PASSWORD" | base64)"
else
  log "[ERROR] 'base64' not found, cannot build Authorization header"
  exit 1
fi
log "[DEBUG] KasmVNC Basic auth header (base64) prepared"

# ---------- XFCE + OpenCPN autostart ----------
log "[INFO] Configuring XFCE autostart for OpenCPN..."
mkdir -p /root/.config/autostart
cat >/root/.config/autostart/opencpn.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=OpenCPN
Exec=opencpn
X-GNOME-Autostart-enabled=true
EOF

# ---------- KasmVNC xstartup (full XFCE) ----------
log "[INFO] Writing KasmVNC xstartup (XFCE session)..."
mkdir -p /root/.vnc
cat >/root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
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

logging:
  log_writer_name: all
  log_dest: logfile
  level: 30

data_loss_prevention:
  clipboard:
    server_to_client:
      enabled: true
      size: unlimited
      primary_clipboard_enabled: true
    client_to_server:
      enabled: true
      size: unlimited

encoding:
  max_frame_rate: 60

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
log "[INFO] Starting KasmVNC (vncserver) on display '${DISPLAY}' (HTTP :${INTERNAL_PORT}, HTTP BasicAuth ENABLED)..."

if command -v timeout >/dev/null 2>&1; then
  timeout 3 vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
else
  vncserver -kill "${DISPLAY}" >/dev/null 2>&1 || true
fi

vncserver "${DISPLAY}" \
  -geometry "${VNC_RESOLUTION}" \
  >/var/log/kasmvncserver.log 2>&1 &

# Wait for KasmVNC HTTP to come up
if command -v curl >/dev/null 2>&1; then
  for i in {1..30}; do
    if curl -sI "http://127.0.0.1:${INTERNAL_PORT}/" >/dev/null 2>&1; then
      log "[INFO] KasmVNC is listening on http://127.0.0.1:${INTERNAL_PORT}/"
      break
    fi
    sleep 1
  done
fi


# ---------- nginx config ----------
log "[INFO] Writing nginx config..."
mkdir -p /var/log/nginx

cat >/etc/nginx/nginx.conf <<EOF
worker_processes  1;

events { worker_connections 1024; }

http {
  include       mime.types;
  default_type  application/octet-stream;

  log_format main '\$remote_addr - \$remote_user [\$time_local] '
                  '"\$request" \$status \$body_bytes_sent '
                  'upstream_status=\$upstream_status '
                  'ref="\$http_referer" ua="\$http_user_agent" '
                  'upgrade="\$http_upgrade" connection="\$http_connection" '
                  'rt=\$request_time urt=\$upstream_response_time';

  access_log  /var/log/nginx/access.log  main;
  error_log   /var/log/nginx/error.log   debug;

  server {
    listen ${NGINX_PORT};
    server_name _;

    # IMPORTANT for ingress: never redirect to an absolute external URL
    # (your logs showed Location: http://test.runnacraft.net:8099/vnc.html)
    location = / {
      return 302 /vnc.html;
    }

    location / {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;

      # Inject HTTP Basic so KasmVNC is always happy
      proxy_set_header Authorization "Basic ${KASMVNC_B64_AUTH}";

      proxy_buffering off;
      proxy_request_buffering off;

      proxy_pass http://127.0.0.1:${INTERNAL_PORT};
    }
  }
}
EOF

# Validate config early (fail fast)
nginx -t

# ---------- Start nginx ----------
log "[INFO] Starting nginx proxy on :${NGINX_PORT}..."
nginx

# Wait for nginx to listen
if command -v curl >/dev/null 2>&1; then
  for i in {1..30}; do
    if curl -sI "http://127.0.0.1:${NGINX_PORT}/" >/dev/null 2>&1; then
      log "[INFO] nginx is listening at http://127.0.0.1:${NGINX_PORT}/"
      break
    fi
    sleep 1
  done
fi

log "[INFO] Ready. Use Home Assistant ingress; no direct ports exposed."
log "[INFO] Tailing logs: /var/log/kasmvncserver.log /root/.vnc/*.log /var/log/nginx/access.log /var/log/nginx/error.log"

shopt -s nullglob
LOGS=(/var/log/kasmvncserver.log /root/.vnc/*.log /var/log/nginx/access.log /var/log/nginx/error.log)
if (( ${#LOGS[@]} > 0 )); then
  tail -F "${LOGS[@]}"
else
  log "[WARN] No log files found to tail; sleeping forever."
  sleep infinity
fi
