#!/bin/bash
set -Eeuo pipefail

# ------------ Config & defaults ------------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_PATH="/data/options.json"

# Display & desktop
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"

# KasmVNC network mode
# - Default: HTTP on 6080 (matches add-on webui/ports)
KASMVNC_USE_HTTPS="${KASMVNC_USE_HTTPS:-false}"   # set to "true" to use HTTPS
NOVNC_PORT="${NOVNC_PORT:-6080}"                  # HTTP port when KASMVNC_USE_HTTPS=false
HTTPS_PORT_DEFAULT=$((8443 + ${DISPLAY#:}))       # 8444 for :1

# Options from HA (options.json), with env fallbacks
jq_get() {
  local key="$1" default="${2:-}"
  if [[ -f "$CONFIG_PATH" ]]; then
    local val
    val="$(jq -r "$key // empty" "$CONFIG_PATH" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "null" ]]; then echo "$val"; return 0; fi
  fi
  echo "$default"
}

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

log "[INFO] Starting OpenCPN Home Assistant add-on"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

MASKED_PASS=""; [[ -n "${VNC_PASSWORD:-}" ]] && MASKED_PASS="******"
log "[DEBUG] display='${DISPLAY}', resolution='${VNC_RESOLUTION}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED_PASS}'"
log "[DEBUG] kasmvnc_use_https='${KASMVNC_USE_HTTPS}', http_port='${NOVNC_PORT}', https_port_default='${HTTPS_PORT_DEFAULT}'"

# ------------ Sanity checks ------------
if ! command -v kasmvncserver >/dev/null 2>&1; then
  log "[ERROR] 'kasmvncserver' not found in PATH!"; exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  log "[WARN] 'jq' not found; options.json parsing may be limited."
fi

# ------------ DBus ------------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
pgrep -x dbus-daemon >/dev/null 2>&1 || dbus-daemon --system --fork

# ------------ Auth (KasmVNC basic auth) ------------
if [[ "$INSECURE_MODE" == "true" && -z "${VNC_PASSWORD:-}" ]]; then
  # Keep it simple: still set a weak password so the server starts,
  # and clearly log that this is insecure.
  VNC_PASSWORD="opencpn"
  log "[WARN] insecure_mode=true and no password provided; using default 'opencpn' (INSECURE)"
fi

if [[ -z "${VNC_PASSWORD:-}" ]]; then
  log "[ERROR] No VNC password set. Provide 'vnc_password' or enable insecure_mode."; exit 1
fi

log "[INFO] Setting KasmVNC password for user 'root'..."
printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root /root/.kasmpasswd
chmod 600 /root/.kasmpasswd || true

# ------------ KasmVNC server config ------------
mkdir -p /etc/kasmvnc

if [[ "$KASMVNC_USE_HTTPS" == "true" ]]; then
  # HTTPS (self-signed) on default 8443 + display (8444 for :1)
  KASMVNC_PORT="${HTTPS_PORT_DEFAULT}"
  cat >/etc/kasmvnc/kasmvnc.yaml <<EOF
network:
  interface: 0.0.0.0
  protocol: http
  websocket_port: ${KASMVNC_PORT}
  ssl:
    require_ssl: true
EOF
  ACCESS_URL="https://[HOST]:${KASMVNC_PORT}/"
else
  # Plain HTTP on NOVNC_PORT (6080 by default)
  KASMVNC_PORT="${NOVNC_PORT}"
  cat >/etc/kasmvnc/kasmvnc.yaml <<EOF
network:
  interface: 0.0.0.0
  protocol: http
  websocket_port: ${KASMVNC_PORT}
  ssl:
    require_ssl: false
EOF
  ACCESS_URL="http://[HOST]:${KASMVNC_PORT}/"
fi

# ------------ Start KasmVNC ------------
log "[INFO] Starting KasmVNC on display '${DISPLAY}' (port ${KASMVNC_PORT})..."
# Clean stale display if any
kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
# Geometry is honored by KasmVNC as WxH
kasmvncserver ":${DISPLAY#:}" -geometry "${VNC_RESOLUTION}"

# Debug listeners
sleep 1
log "[DEBUG] Listening sockets for kasmvnc (after start):"
ss -ltnp 2>/dev/null | awk 'NR==1 || /kasmvnc/ {print}'

# ------------ Desktop session ------------
export DISPLAY
log "[INFO] Launching XFCE desktop..."
mkdir -p /root/.vnc
startxfce4 >/root/.vnc/xfce.log 2>&1 &

# ------------ Launch OpenCPN ------------
if command -v opencpn >/dev/null 2>&1; then
  log "[INFO] Launching OpenCPN..."
  opencpn >/root/.vnc/opencpn.log 2>&1 &
else
  log "[ERROR] 'opencpn' not found in PATH."
fi

# ------------ Ready ------------
log "[INFO] Ready. Open your browser to: ${ACCESS_URL}"
log "[INFO] Username: root  (password set via options.json / env)"

# Keep container in foreground
shopt -s nullglob
LOGS=(/root/.vnc/*.log)
if (( ${#LOGS[@]} > 0 )); then
  tail -F "${LOGS[@]}"
else
  sleep infinity
fi
