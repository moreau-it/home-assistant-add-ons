#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

# Read configuration from options.json
INSECURE_MODE=$(jq -r '.insecure_mode // true' ${CONFIG_PATH})

# Set environment
export DISPLAY=:1
export VNC_RESOLUTION=${VNC_RESOLUTION:-1280x800}
export NOVNC_PORT=${NOVNC_PORT:-6080}
export VNC_PORT=5901
export XAUTHORITY=/root/.Xauthority

# Prepare X startup script
mkdir -p /root/.vnc
cat > /root/.xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XAUTHORITY=/root/.Xauthority
dbus-launch --exit-with-session startxfce4
EOF
chmod +x /root/.xstartup

# Function to start Xvfb + XFCE
start_x() {
    echo "[INFO] Starting Xvfb on display ${DISPLAY}..."
    Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION}x24 &
    XVFB_PID=$!
    echo "[INFO] Starting XFCE session..."
    /root/.xstartup &
    XFCE_PID=$!
}

# Function to start noVNC
start_novnc() {
    echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..."
    websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &
    NOVNC_PID=$!
}

# Function to start OpenCPN
start_opencpn() {
    echo "[INFO] Launching OpenCPN..."
    opencpn &
    OCPN_PID=$!
}

# Clean up any previous Xvfb processes
echo "[INFO] Cleaning previous Xvfb sessions..."
pkill -f Xvfb || true

# Start services
start_x
start_novnc
start_opencpn

# Monitor processes and restart if they crash
while true; do
    sleep 5
    if ! ps -p $XVFB_PID > /dev/null; then
        echo "[WARN] Xvfb crashed, restarting..."
        start_x
    fi
    if ! ps -p $OCPN_PID > /dev/null; then
        echo "[WARN] OpenCPN crashed, restarting..."
        start_opencpn
    fi
done
