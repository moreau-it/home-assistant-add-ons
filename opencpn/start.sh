#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
LOGFILE=/data/openocpn.log
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Add timestamped header
echo "################${DATE}################" >> "$LOGFILE"

echo "[INFO] Starting OpenCPN Home Assistant Add-on..." | tee -a "$LOGFILE"
echo "[DEBUG] Loading configuration from ${CONFIG_PATH}..." | tee -a "$LOGFILE"

VNC_PASSWORD=$(jq -r '.vnc_password // empty' ${CONFIG_PATH})
INSECURE_MODE=$(jq -r '.insecure_mode // false' ${CONFIG_PATH})

# Mask password in logs
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
else
    MASKED_PASS=""
fi

echo "[DEBUG] vnc_password='${MASKED_PASS}'" | tee -a "$LOGFILE"
echo "[DEBUG] insecure_mode='${INSECURE_MODE}'" | tee -a "$LOGFILE"

# Log current PATH
echo "[DEBUG] Current PATH: $PATH" | tee -a "$LOGFILE"

# Check if kasmvncserver exists
KASM_PATH=$(command -v kasmvncserver || true)
if [ -z "$KASM_PATH" ]; then
    echo "[ERROR] kasmvncserver not found in PATH!" | tee -a "$LOGFILE"
    echo "[DEBUG] /usr/local/bin contents:" >> "$LOGFILE"
    ls -l /usr/local/bin >> "$LOGFILE"
else
    echo "[DEBUG] kasmvncserver found at: $KASM_PATH" | tee -a "$LOGFILE"
fi

# Start DBus
echo "[INFO] Starting DBus..." | tee -a "$LOGFILE"
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Configure KasmVNC
if [ "$INSECURE_MODE" = "true" ]; then
    echo "[INFO] Starting KasmVNC in INSECURE mode..." | tee -a "$LOGFILE"
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    if [ -z "$VNC_PASSWORD" ] || [ "$VNC_PASSWORD" = "null" ]; then
        echo "[ERROR] VNC password not set! Either enable insecure mode or provide a password." | tee -a "$LOGFILE"
        exit 1
    fi
    echo "[INFO] Setting KasmVNC password..." | tee -a "$LOGFILE"
    mkdir -p /root/.vnc
    (echo "$VNC_PASSWORD" && echo "$VNC_PASSWORD") | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    KASM_CMD="kasmvncserver :1 -geometry ${VNC_RESOLUTION} -rfbauth /root/.vnc/passwd"
fi

# Start KasmVNC
echo "[INFO] Starting KasmVNC server on display :1..." | tee -a "$LOGFILE"
eval $KASM_CMD &>> "$LOGFILE" &

# Start noVNC
echo "[INFO] Starting noVNC on port ${NOVNC_PORT}..." | tee -a "$LOGFILE"
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT} &>> "$LOGFILE" &

# Start XFCE
echo "[INFO] Launching XFCE desktop environment..." | tee -a "$LOGFILE"
export DISPLAY=:1
startxfce4 &>> "$LOGFILE" &

# Wait a bit before OpenCPN
sleep 3
echo "[INFO] Launching OpenCPN..." | tee -a "$LOGFILE"
opencpn &>> "$LOGFILE" &

echo "[INFO] OpenCPN with KasmVNC & noVNC is now running!" | tee -a "$LOGFILE"

tail -F /root/.vnc/*.log
