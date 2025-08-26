#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
echo "[INFO] Starting OpenCPN Home Assistant Add-on..."

# Start Xvfb
echo "[INFO] Starting headless X server (Xvfb)..."
Xvfb :1 -screen 0 ${VNC_RESOLUTION}x24 &

# Allow some time for Xvfb
sleep 2

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:5901 &

# Start XFCE session
echo "[INFO] Starting XFCE..."
/root/.xstartup &

# Give XFCE some time
sleep 3

# Start OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with noVNC is now running!"
# Keep container alive
tail -f /dev/null
