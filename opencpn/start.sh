#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
VNC_PASSWD_FILE=/root/.vnc/passwd

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loaded options.json:"
cat $CONFIG_PATH

VNC_PASSWORD=$(jq -r '.vnc_password // ""' "$CONFIG_PATH")
INSECURE_MODE=$(jq -r '.insecure_mode // false' "$CONFIG_PATH")

# Check password or insecure mode
if [ "$INSECURE_MODE" != "true" ] && [ -z "$VNC_PASSWORD" ]; then
    echo "[ERROR] No VNC password set! Enable insecure mode or add a password."
    exit 1
fi

# Configure password if provided
if [ -n "$VNC_PASSWORD" ]; then
    echo "$VNC_PASSWORD" | vncpasswd -f > $VNC_PASSWD_FILE
    chmod 600 $VNC_PASSWD_FILE
    VNC_AUTH_OPTS="-rfbauth $VNC_PASSWD_FILE"
else
    VNC_AUTH_OPTS="--I-KNOW-THIS-IS-INSECURE -SecurityTypes None"
fi

# Start dbus first
echo "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Start VNC server
echo "[INFO] Starting TigerVNC..."
vncserver :1 -geometry ${VNC_RESOLUTION:-1280x800} $VNC_AUTH_OPTS

# Start noVNC
echo "[INFO] Starting noVNC on port 6080..."
websockify --web=/usr/share/novnc/ 0.0.0.0:6080 localhost:5901 &

# Start XFCE with dbus-launch
echo "[INFO] Starting XFCE desktop..."
dbus-launch --exit-with-session startxfce4 &

# Start OpenCPN
sleep 3
echo "[INFO] Launching OpenCPN..."
opencpn &

tail -F /root/.vnc/*.log
