#!/bin/bash
set -e

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."

CONFIG_PATH=/data/options.json

# Log the entire config for debugging
echo "[DEBUG] Loaded options.json:"
cat $CONFIG_PATH

VNC_PASS=$(jq -r '.vnc_password' "$CONFIG_PATH")
INSECURE_MODE=$(jq -r '.insecure_mode' "$CONFIG_PATH")

echo "[DEBUG] vnc_password = '$VNC_PASS'"
echo "[DEBUG] insecure_mode = '$INSECURE_MODE'"

# Check if password exists OR insecure mode enabled
if [[ "$VNC_PASS" == "null" || -z "$VNC_PASS" ]]; then
    if [[ "$INSECURE_MODE" != "true" ]]; then
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

# Start noVNC
echo "[INFO] Starting noVNC on port 6080..."
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 &

# Configure XFCE session if missing
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

# Keep container running
echo "[INFO] OpenCPN add-on running. Connect via VNC or http://<homeassistant>:6080"
tail -F /root/.vnc/*.log
