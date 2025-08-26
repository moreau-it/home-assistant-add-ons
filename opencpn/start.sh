#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

VNC_PASSWORD=$(jq -r '.vnc_password // empty' ${CONFIG_PATH})
INSECURE_MODE=$(jq -r '.insecure_mode // true' ${CONFIG_PATH})

if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
else
    MASKED_PASS=""
fi

echo "[DEBUG] vnc_password='${MASKED_PASS}'"
echo "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Clean previous sessions
vncserver -kill :1 || true
rm -rf /root/.vnc/*.pid

# Prepare Xauthority
export XAUTHORITY=/root/.Xauthority
touch "$XAUTHORITY"

# Start VNC
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting VNC in INSECURE mode..."
    vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set!"
        exit 1
    fi
    echo "[INFO] Setting VNC password..."
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    echo "[INFO] Starting VNC with password authentication..."
    vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -rfbauth /root/.vnc/passwd
fi

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

# Give XFCE some time
sleep 3

# Start OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with VNC & noVNC is now running!"
tail -F /root/.vnc/*.log
