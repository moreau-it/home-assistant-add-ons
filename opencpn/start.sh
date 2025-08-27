#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
LOGFILE=/var/log/opencpn_addon.log

# Function to log with timestamp
log() {
    echo "################$(date '+%Y-%m-%d %H:%M:%S')#################"
    echo "$1" | tee -a "$LOGFILE"
}

log "[INFO] Starting OpenCPN Home Assistant Add-on..."
log "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

VNC_PASSWORD=$(jq -r '.vnc_password // empty' ${CONFIG_PATH})
INSECURE_MODE=$(jq -r '.insecure_mode // false' ${CONFIG_PATH})

# Mask password in logs
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
else
    MASKED_PASS=""
fi

log "[DEBUG] vnc_password='${MASKED_PASS}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Start DBus
log "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Find kasmvncserver binary
KASM_PATH=$(command -v kasmvncserver || true)
if [ -n "$KASM_PATH" ]; then
    log "[DEBUG] kasmvncserver binary location: $KASM_PATH"
else
    log "[ERROR] kasmvncserver not found in PATH!"
    log "[DEBUG] /usr/local/bin contents:"
    ls -l /usr/local/bin | tee -a "$LOGFILE"
fi

# Configure KasmVNC
if [ "$INSECURE_MODE" = "true" ]; then
    log "[INFO] Starting KasmVNC in INSECURE mode..."
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        log "[ERROR] VNC password not set! Either enable insecure mode or provide a password."
        exit 1
    fi
    log "[INFO] Setting KasmVNC password..."
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -rfbauth /root/.vnc/passwd"
fi

# Start KasmVNC
log "[INFO] Starting KasmVNC server on display :1..."
eval $KASM_CMD

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

log "[INFO] OpenCPN with KasmVNC & noVNC is now running!"
tail -F /root/.vnc/*.log
