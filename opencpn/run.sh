#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
DISPLAY=:1
VNC_RESOLUTION=${VNC_RESOLUTION:-1280x800}
NOVNC_PORT=${NOVNC_PORT:-6080}
LD_LIBRARY_PATH=/usr/local/lib

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

# Read configuration from options.json
INSECURE_MODE=$(jq -r '.insecure_mode // true' ${CONFIG_PATH})

echo "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Prepare X11 environment
mkdir -p /root/.vnc
export XAUTHORITY=/root/.Xauthority
if [ ! -f "$XAUTHORITY" ]; then
    echo "[INFO] Creating new Xauthority file..."
    touch "$XAUTHORITY"
fi

# Start DBus for XFCE
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Start Xvfb (headless X server)
echo "[INFO] Starting Xvfb on display ${DISPLAY}..."
Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION}x24 &

# Start XFCE session
echo "[INFO] Starting XFCE desktop environment..."
export DISPLAY=${DISPLAY}
dbus-launch --exit-with-session startxfce4 &

# Start noVNC to expose display via browser
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
x11vnc -display ${DISPLAY} -nopw -forever -shared -bg -rfbport 5900
websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:5900 &

# Delay to allow XFCE to fully start
sleep 3

# Start OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with noVNC is now running!"
# Keep container alive
tail -F /root/.vnc/*.log || tail -f /dev/null
