#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

# Read configuration
INSECURE_MODE=$(jq -r '.insecure_mode // true' ${CONFIG_PATH})
VNC_RESOLUTION=$(jq -r '.vnc_resolution // "1280x800"' ${CONFIG_PATH})
NOVNC_PORT=$(jq -r '.novnc_port // 6080' ${CONFIG_PATH})

# Start DBus
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Start Xvfb (virtual framebuffer)
echo "[INFO] Starting Xvfb on display ${DISPLAY} with resolution ${VNC_RESOLUTION}..."
Xvfb $DISPLAY -screen 0 $VNC_RESOLUTIONx24 &

# Start XFCE desktop environment
echo "[INFO] Launching XFCE desktop environment..."
export DISPLAY=$DISPLAY
dbus-launch --exit-with-session startxfce4 &

# Start noVNC server
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc $NOVNC_PORT localhost:5900 &

# Delay to allow XFCE to start
sleep 3

# Launch OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

# Keep container running
tail -f /dev/null
