#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

# Read configuration from options.json
VNC_PASSWORD=$(jq -r '.vnc_password // empty' ${CONFIG_PATH})
INSECURE_MODE=$(jq -r '.insecure_mode // false' ${CONFIG_PATH})

# Mask password in logs
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
else
    MASKED_PASS=""
fi

echo "[DEBUG] vnc_password='${MASKED_PASS}'"
echo "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Prepare VNC environment
mkdir -p /root/.vnc
export XAUTHORITY=/root/.Xauthority
touch "$XAUTHORITY"

# Start DBus
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Configure VNC server
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting VNC in INSECURE mode..."
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set!"
        exit 1
    fi
    echo "[INFO] Setting VNC password..."
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -rfbauth /root/.vnc/passwd"
fi

# Start VNC server
echo "[INFO] Starting TigerVNC server on display :1..."
eval $VNC_CMD

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

# Container is now running; logs will show status
echo "[INFO] OpenCPN with VNC & noVNC is now running!"
tail -F /root/.vnc/*.log
