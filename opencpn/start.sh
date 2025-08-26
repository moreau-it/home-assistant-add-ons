#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

# Read configuration
VNC_PASSWORD=$(jq -r '.vnc_password // "opencpn"' ${CONFIG_PATH})
INSECURE_MODE=$(jq -r '.insecure_mode // true' ${CONFIG_PATH})

echo "[DEBUG] vnc_password='******'"
echo "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Clean old Xvfb sessions
echo "[INFO] Cleaning previous X server sessions..."
pkill Xvfb || true

# Start DBus
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Start virtual X server
echo "[INFO] Starting virtual X server on display ${DISPLAY}..."
Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION}x24 &

# Allow some time for Xvfb to start
sleep 2

# Start XFCE in background
echo "[INFO] Launching XFCE desktop environment..."
export DISPLAY=${DISPLAY}
dbus-launch --exit-with-session startxfce4 &

sleep 3

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
if [ "${INSECURE_MODE}" = "true" ]; then
    websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:5900 &
else
    echo "[INFO] Using VNC password authentication..."
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | x11vnc -storepasswd /root/.vnc/passwd
    websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:5900 --cert /root/.vnc/cert.pem --key /root/.vnc/key.pem &
fi

# Launch OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with noVNC is now running!"
# Keep container alive
tail -f /dev/null
