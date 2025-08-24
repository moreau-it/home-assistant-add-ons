#!/bin/bash
set -e

CONFIG_PATH="/data/options.json"

# Read config from Home Assistant
VNC_PASSWORD=$(jq -r '.vnc_password // empty' $CONFIG_PATH)
VNC_AUTH_REQUIRED=$(jq -r '.vnc_auth_required // false' $CONFIG_PATH)

echo "[INFO] Starting OpenCPN with VNC + USB autodetect"

# -----------------------------------------
# 🔹 USB Device Autodetection
# -----------------------------------------
echo "[INFO] Detecting USB serial devices..."
USB_DEVICES=$(ls /dev/ttyUSB* /dev/ttyAMA* /dev/serial/by-id/* 2>/dev/null || true)

if [ -n "$USB_DEVICES" ]; then
    echo "[INFO] Found USB serial devices:"
    echo "$USB_DEVICES"
else
    echo "[WARN] No USB serial devices detected!"
fi

# -----------------------------------------
# 🔹 Configure TigerVNC authentication
# -----------------------------------------
if [ "$VNC_AUTH_REQUIRED" = "true" ] && [ -n "$VNC_PASSWORD" ]; then
    echo "[INFO] Using password-protected VNC session"
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    vncserver :1 -geometry $VNC_RESOLUTION -rfbauth /root/.vnc/passwd -localhost no
else
    echo "[WARN] Starting TigerVNC in INSECURE mode!"
    vncserver :1 -geometry $VNC_RESOLUTION -localhost no --I-KNOW-THIS-IS-INSECURE
fi

# -----------------------------------------
# 🔹 Start noVNC (Web VNC)
# -----------------------------------------
if [ -d "$NOVNC_HOME" ]; then
    echo "[INFO] Starting noVNC on port $NOVNC_PORT"
    websockify --web=$NOVNC_HOME $NOVNC_PORT localhost:5901 &
else
    echo "[WARN] noVNC not installed, skipping web VNC"
fi

# -----------------------------------------
# 🔹 Start XFCE & OpenCPN
# -----------------------------------------
echo "[INFO] Starting XFCE desktop + OpenCPN..."
mkdir -p ~/.vnc
cat <<EOF > ~/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
sleep 2
opencpn &
EOF
chmod +x ~/.vnc/xstartup

/root/.vnc/xstartup &

# -----------------------------------------
# Keep container alive
# -----------------------------------------
tail -F /root/.vnc/*.log
