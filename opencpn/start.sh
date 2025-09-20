#!/bin/bash
set -Eeuo pipefail

# ---------- Paths & defaults ----------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

# Display & desktop sizing
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# Serve on this port. Both HTTP and HTTPS will work here when require_ssl=false.
# Use KASMVNC_PORT env to override, or NOVNC_PORT for backward-compat.
KASMVNC_PORT="${KASMVNC_PORT:-${NOVNC_PORT:-6080}}"

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

# DO NOT USE IN PRODUCTION.
# For testing only: default password if insecure_mode=true and no password provided.
VNC_PASSWORD='ChangeMe123'

INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

MASKED=""; [[ -n "${VNC_PASSWORD:-}" ]] && MASKED="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED}'"
log "[DEBUG] kasmvnc_port='${KASMVNC_PORT}' (HTTP and HTTPS)"

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

# ---------- KasmVNC server config ----------
# Docs: network.protocol=http|vnc, websocket_port (auto=8443+DISPLAY), ssl.require_ssl (default true).
# We set protocol=http, pick our port, and set require_ssl=false so BOTH HTTP and HTTPS work on that port.
# On Debian, default "system" cert is used for TLS (snake-oil) unless you provide your own. 
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
log "[INFO] Starting KasmVNC on display '${DISPLAY}' (HTTP+HTTPS :${KASMVNC_PORT})..."
kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
kasmvncserver ":${DISPLAY#:}" -geometry "${VNC_RESOLUTION}"

# ---------- Verify listeners (up to 12s) ----------
ok_http=false
ok_https=false
for i in {1..12}; do
  curl -sI "http://127.0.0.1:${KASMVNC_PORT}/" >/dev/null 2>&1 && ok_http=true || true
  curl -skI "https://127.0.0.1:${KASMVNC_PORT}/" >/dev/null 2>&1 && ok_https=true || true
  if $ok_http || $ok_https; then break; fi
  sleep 1
done
$ok_http  && log "[INFO] HTTP listening at  http://127.0.0.1:${KASMVNC_PORT}/"
$ok_https && log "[INFO] HTTPS listening at https://127.0.0.1:${KASMVNC_PORT}/"
if ! $ok_http && ! $ok_https; then
  log "[ERROR] KasmVNC did not open port ${KASMVNC_PORT}"; 
  ss -ltnp 2>/dev/null | awk 'NR==1 || /kasmvnc/' || true
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

# Keep container in foreground
shopt -s nullglob
LOGS=(/root/.vnc/*.log)
if (( ${#LOGS[@]} > 0 )); then
  tail -F "${LOGS[@]}"
else
  sleep infinity
fi
