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

# Prepare XFCE and DBus
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Configure password for KasmVNC
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting KasmVNC in INSECURE mode (no password)..."
    kasmvncserver --geometry ${VNC_RESOLUTION} --localhost no --vnc :1 --skip-auth
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set! Either enable insecure mode or provide a password."
        exit 1
    fi
    echo "[INFO] Setting KasmVNC password..."
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    kasmvncserver --geometry ${VNC_RESOLUTION} --vnc :1 --passwd /root/.vnc/passwd
fi

# Start XFCE
echo "[INFO] Launching XFCE desktop..."
export DISPLAY=:1
dbus-launch --exit-with-session startxfce4 &

# Wait a bit
sleep 3

# Launch OpenCPN
echo "[INFO] Launching OpenCPN..."
opencpn &

echo "[INFO] OpenCPN with KasmVNC is now running at http://<host>:6901/"
tail -f /root/.vnc/*.log
