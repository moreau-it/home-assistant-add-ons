#!/bin/bash
set -e

# Add /usr/local/bin to PATH
export PATH=/usr/local/bin:$PATH

CONFIG_PATH=/data/options.json

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')$*"; }

log "[INFO] Starting OpenCPN Home Assistant Add-on..."
log "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

VNC_PASSWORD=$(jq -r '.vnc_password // empty' "${CONFIG_PATH}")
INSECURE_MODE=$(jq -r '.insecure_mode // false' "${CONFIG_PATH}")

MASKED_PASS=""
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
fi
log "[DEBUG] vnc_password='${MASKED_PASS}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Start DBus
log "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Check if vncserver exists in PATH
if ! command -v vncserver >/dev/null 2>&1; then
    log "[ERROR] 'vncserver' not found in PATH! Please check your build."
    exit 1
fi
log "[DEBUG] Found 'vncserver' in PATH at: $(command -v vncserver)"

# Configure VNC command
if [ "$INSECURE_MODE" = "true" ]; then
    log "[INFO] Starting VNC in INSECURE mode..."
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        log "[ERROR] VNC password not set! Either enable insecure mode or provide a password."
        exit 1
    fi
    log "[INFO] Setting VNC password..."
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -rfbauth /root/.vnc/passwd"
fi

# Start VNC
log "[INFO] Starting VNC server on display :1..."
eval $VNC_CMD

# Start noVNC
log "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

# Start XFCE
log "[INFO] Launching XFCE desktop environment..."
export DISPLAY=:1
startxfce4 &

# Wait a bit before OpenCPN
sleep 3
log "[INFO] Launching OpenCPN..."
opencpn &

log "[INFO] OpenCPN with VNC & noVNC is now running!"
tail -F /root/.vnc/*.log
