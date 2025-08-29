#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

# Display & desktop sizing
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# We’ll serve HTTP on 6080 (matches your add-on config/webui)
KASMVNC_PORT="${NOVNC_PORT:-6080}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

jq_get() {
  local key="$1" default="${2:-}"
  if [[ -f "$CONFIG_PATH" ]]; then
    local val
    val="$(jq -r "$key // empty" "$CONFIG_PATH" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "null" ]]; then echo "$val"; return 0; fi
  fi
  echo "$default"
}

log "[INFO] Starting OpenCPN Home Assistant add-on"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

MASKED=""; [[ -n "${VNC_PASSWORD:-}" ]] && MASKED="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED}'"
log "[DEBUG] kasmvnc_http_port='${KASMVNC_PORT}'"

# ---------- Sanity checks ----------
command -v kasmvncserver >/dev/null 2>&1 || { log "[ERROR] kasmvncserver not found"; exit 1; }
command -v jq >/dev/null 2>&1 || log "[WARN] 'jq' not found; options.json parsing may be limited."

# ---------- DBus ----------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ---------- Auth ----------
if [[ "$INSECURE_MODE" == "true" && -z "${VNC_PASSWORD:-}" ]]; then
  VNC_PASSWORD="opencpn"
  log "[WARN] insecure_mode=true and no password provided; using default 'opencpn' (INSECURE)"
fi
if [[ -z "${VNC_PASSWORD:-}" ]]; then
  log "[ERROR] No VNC password set. Provide 'vnc_password' or enable insecure_mode."
  exit 1
fi

log "[INFO] Setting KasmVNC password for user 'root'..."
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# ---------- KasmVNC server config (HTTP on 6080) ----------
mkdir -p /etc/kasmvnc
cat >/etc/kasmvnc/kasmvnc.yaml <<EOF
network:
  interface: 0.0.0.0
  protocol: http
  websocket_port: ${KASMVNC_PORT}
  ssl:
    require_ssl: false
EOF

# ---------- Start KasmVNC ----------
log "[INFO] Starting KasmVNC on display '${DISPLAY}' (HTTP :${KASMVNC_PORT})..."
kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
kasmvncserver ":${DISPLAY#:}" -geometry "${VNC_RESOLUTION}"

# ---------- Verify listener (up to 10s) ----------
for i in {1..10}; do
  if curl -sI "http://127.0.0.1:${KASMVNC_PORT}/" >/dev/null 2>&1; then
    log "[INFO] KasmVNC is listening on http://127.0.0.1:${KASMVNC_PORT}/"
    break
  fi
  sleep 1
  [[ $i -eq 10 ]] && { 
    log "[ERROR] KasmVNC did not open port ${KASMVNC_PORT}"; 
    tail -n +1 ~/.vnc/*.log 2>/dev/null || true
  }
done

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
log "[INFO] Ready. Open your browser to: http://[HOST]:${KASMVNC_PORT}/"
log "[INFO] Username: root  (password from options.json / env)"

# Keep container in foreground
shopt -s nullglob
LOGS=(/root/.vnc/*.log)
if (( ${#LOGS[@]} > 0 )); then
  tail -F "${LOGS[@]}"
else
  sleep infinity
fi
