#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
VNC_PASSWD_FILE=/root/.vnc/passwd

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loaded options.json:"
cat $CONFIG_PATH

# Extract config values using jq
VNC_PASSWORD=$(jq -r '.vnc_password // ""' "$CONFIG_PATH")
INSECURE_MODE=$(jq -r '.insecure_mode // false' "$CONFIG_PATH")

echo "[DEBUG] vnc_password = '$VNC_PASSWORD'"
echo "[DEBUG] insecure_mode = '$INSECURE_MODE'"

# Ensure the .vnc directory exists
mkdir -p /root/.vnc

# If insecure mode is disabled but no password provided → fail
if [ "$INSECURE_MODE" != "true" ] && [ -z "$VNC_PASSWORD" ]; then
    echo "[ERROR] No VNC password set! Enable insecure mode or add a password."
    exit 1
fi

# Configure password if provided
if [ -n "$VNC_PASSWORD" ]; then
    echo "[INFO] Setting VNC password."
    echo "$VNC_PASSWORD" | vncpasswd -f > $VNC_PASSWD_FILE
    chmod 600 $VNC_PASSWD_FILE
    VNC_AUTH_OPTS="-rfbauth $VNC_PASSWD_FILE"
else
    echo "[INFO] Starting VNC in INSECURE mode (no authentication)."
    VNC_AUTH_OPTS="--I-KNOW-THIS-IS-INSECURE -SecurityTypes None"
fi

# Export DISPLAY
export DISPLAY=:1
export XAUTHORITY=/root/.Xauthority

# Start TigerVNC server
echo "[INFO] Starting TigerVNC server on :1"
vncserver :1 -geometry ${VNC_RESOLUTION:-1280x800} $VNC_AUTH_OPTS

# Start noVNC (web-based VNC)
echo "[INFO] Starting noVNC on port 6080"
websockify --web=/usr/share/novnc/ 0.0.0.0:6080 localhost:5901 &

# Start XFCE desktop environment
echo "[INFO] Starting XFCE4 desktop environment"
dbus-launch startxfce4 &

# Start OpenCPN automatically after desktop is ready
sleep 3
echo "[INFO] Starting OpenCPN..."
opencpn &

# Tail VNC logs for Home Assistant visibility
echo "[INFO] Tailing VNC logs..."
tail -F /root/.vnc/*.log
