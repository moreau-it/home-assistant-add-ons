#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

# Display & desktop sizing
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# Serve on this port. Both HTTP and HTTPS can work here (ssl.require_ssl=false).
# Env precedence: KASMVNC_PORT > NOVNC_PORT > config.json > 6080
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
command -v kasmvncserver >/dev/null 2>&1 || { log "[ERROR] kasmvncserver not found"; exit 1; }
command -v jq >/dev/null 2>&1 || log "[WARN] 'jq' not found; options.json parsing may be limited."
command -v curl >/dev/null 2>&1 || log "[WARN] 'curl' not found; health checks will be skipped."

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
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# Non-interactive write permissions: avoid interactive TextUI wizard
log "[INFO] Configuring KasmVNC users and permissions..."
mkdir -p /root/.kasmvnc
echo "root" >/root/.kasmvnc/allowed_users
chmod 600 /root/.kasmvnc/allowed_users || true

# ---------- KasmVNC server config ----------
log "[INFO] Creating /etc/kasmvnc configuration..."
mkdir -p /etc/kasmvnc

cat >/etc/kasmvnc/kasmvnc.yaml <<EOF
users:
  root:
    allow_writes: true

network:
  interface: 0.0.0.0
  protocol: http
  websocket_port: ${KASMVNC_PORT}
  ssl:
    require_ssl: false
EOF

chmod 600 /etc/kasmvnc/kasmvnc.yaml || true

# ---------- Start KasmVNC ----------
log "[INFO] Starting KasmVNC on display '${DISPLAY}' (HTTP+HTTPS :${KASMVNC_PORT})..."

# Best-effort cleanup, but do NOT block indefinitely if it hangs
if command -v timeout >/dev/null 2>&1; then
  timeout 3 kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
else
  kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
fi

# Start in background so we can continue with health checks + desktop
kasmvncserver "${DISPLAY}" \
  --config /etc/kasmvnc/kasmvnc.yaml \
  -geometry "${VNC_RESOLUTION}" >/var/log/kasmvncserver.log 2>&1 &

# ---------- Verify listeners (up to 12s) ----------
ok_http=false
ok_https=false

if command -v curl >/dev/null 2>&1; then
  for i in {1..12}; do
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
  (ss -ltnp 2>/dev/null || netstat -tlnp 2>/dev/null || true) | awk 'NR==1 || /kasmvnc/' || true
fi

# ---------- Desktop session ----------
export DISPLAY
log "[INFO] Launching XFCE desktop..."
mkdir -p /root/.vnc
startxfce4 >/root/.vnc/xfce.log 2>&1 &

# ---------- Launch OpenCPN ----------
if command -v opencpn >/dev/null 2>&1; then
  log "[INFO] Launching OpenCPN..."
  opencpn >/root/.vnc/opencpn.log 2>&1 &
else
  log "[ERROR] 'opencpn' not found in PATH."
fi

# ---------- Ready ----------
log "[INFO] Ready. Open your browser to: http://[HOST]:${KASMVNC_PORT}/  or  https://[HOST]:${KASMVNC_PORT}/"
log "[INFO] Username: root  (password from options.json / env)"

# ---------- Keep container alive ----------
shopt -s nullglob
LOGS=(/root/.vnc/*.log /var/log/kasmvncserver.log)
if (( ${#LOGS[@]} > 0 )); then
  log "[INFO] Tailing logs: ${LOGS[*]}"
  tail -F "${LOGS[@]}"
else
  log "[WARN] No log files found to tail; sleeping forever."
  sleep infinity
fi
