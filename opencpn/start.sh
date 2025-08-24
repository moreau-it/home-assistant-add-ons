#!/bin/bash
set -e

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."

CONFIG_PATH=/data/options.json
VNC_PASS=$(jq -r '.vnc_password' $CONFIG_PATH)
INSECURE_MODE=$(jq -r '.insecure_mode' $CONFIG_PATH)

# If no password and insecure mode disabled → stop and print clear error
if [[ -z "$VNC_PASS" || "$VNC_PASS" == "null" ]]; then
    if [[ "$INSECURE_MODE" == "false" ]]; then
        echo "[ERROR] No VNC password set! Enable insecure mode in config or add a password."
        exit 1
    fi
    echo "[INFO] Starting VNC in INSECURE mode (no authentication)."
    export VNC_OPTIONS="--I-KNOW-THIS-IS-INSECURE -SecurityTypes None"
else
    echo "[INFO] Setting VNC password..."
    mkdir -p /root/.vnc
    echo "$VNC_PASS" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    export VNC_OPTIONS="-PasswordFile /root/.vnc/passwd"
fi

# Start VNC server
vncserver :1 -geometry ${VNC_RESOLUTION:-1280x800} $VNC_OPTIONS

# Start noVNC in background
echo "[INFO] Starting noVNC web interface on port 6080..."
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 &

# Start XFCE session
if [[ ! -f /root/.vnc/xstartup ]]; then
    echo "[INFO] Configuring VNC xstartup..."
    mkdir -p /root/.vnc
    cat <<EOF > /root/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
sleep 2
opencpn &
EOF
    chmod +x /root/.vnc/xstartup
fi

# Keep container running and stream logs
echo "[INFO] OpenCPN add-on running. Connect via VNC or http://<homeassistant>:6080"
tail -F /root/.vnc/*.log
