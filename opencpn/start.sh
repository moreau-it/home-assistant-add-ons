#!/bin/bash
set -e

CONFIG_PATH="/data/options.json"

# Read password + flag from Home Assistant config
VNC_PASSWORD=$(jq -r '.vnc_password // empty' $CONFIG_PATH)
VNC_AUTH_REQUIRED=$(jq -r '.vnc_auth_required // false' $CONFIG_PATH)

echo "[INFO] Starting TigerVNC server on display :1"

# Configure VNC password or insecure mode
if [ "$VNC_AUTH_REQUIRED" = "true" ] && [ -n "$VNC_PASSWORD" ]; then
    echo "[INFO] Setting up password-protected VNC..."
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    vncserver :1 -geometry $VNC_RESOLUTION -rfbauth /root/.vnc/passwd -localhost no
else
    echo "[WARN] Starting TigerVNC without authentication!"
    vncserver :1 -geometry $VNC_RESOLUTION -localhost no --I-KNOW-THIS-IS-INSECURE
fi

# Start noVNC
if [ -d "$NOVNC_HOME" ]; then
    echo "[INFO] Starting noVNC on port $NOVNC_PORT"
    websockify --web=$NOVNC_HOME $NOVNC_PORT localhost:5901 &
else
    echo "[WARN] noVNC is not installed, skipping web VNC"
fi

# Start XFCE session
/root/.vnc/xstartup &

# Start OpenCPN in the foreground
echo "[INFO] Launching OpenCPN..."
exec opencpn
