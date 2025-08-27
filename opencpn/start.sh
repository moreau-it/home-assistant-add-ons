#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

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

# Start DBus
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Configure KasmVNC
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting KasmVNC in INSECURE mode..."
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set! Either enable insecure mode or provide a password."
        exit 1
    fi
    echo "[INFO] Setting KasmVNC password..."
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -rfbauth /root/.vnc/passwd"
fi

# Start KasmVNC
echo "[INFO] Starting KasmVNC server on display :1..."
eval $KASM_CMD

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

# Start XFCE
echo "[INFO] Launching XFCE desktop environment..."
export DISPLAY=:1
startxfce4 &

# Wait a bit before OpenCPN
sleep 3
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with KasmVNC & noVNC is now running!"
tail -F /root/.vnc/*.log
