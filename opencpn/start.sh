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

# Always create a fresh Xauthority file to avoid race conditions
if [ ! -f "$XAUTHORITY" ]; then
    echo "[INFO] Creating new Xauthority file..."
    touch "$XAUTHORITY"
fi

# Start DBus service for XFCE and VNC session
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Configure VNC security options
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting VNC in INSECURE mode (no authentication)..."
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set! Either enable insecure mode or provide a password."
        exit 1
    fi
    echo "[INFO] Setting VNC password..."
    mkdir -p /root/.vnc
    # Create password file non-interactively (no echo to logs)
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    echo "[INFO] Starting VNC with PASSWORD authentication..."
    VNC_CMD="vncserver :1 -geometry ${VNC_RESOLUTION} -localhost no -rfbauth /root/.vnc/passwd"
fi

# Start TigerVNC server
echo "[INFO] Starting TigerVNC server on display :1..."
eval $VNC_CMD

# Start noVNC in background
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &

# Start XFCE session cleanly
echo "[INFO] Launching XFCE desktop environment..."
export DISPLAY=:1
dbus-launch --exit-with-session startxfce4 &

# Delay to allow XFCE to fully start
sleep 3

# Start OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with VNC & noVNC is now running!"
tail -F /root/.vnc/*.log
