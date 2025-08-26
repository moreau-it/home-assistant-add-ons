#!/usr/bin/env bash
set -e

OPTIONS_FILE="/data/options.json"
VNC_PASS=$(jq -r '.vnc_password' $OPTIONS_FILE)
ALLOW_INSECURE=$(jq -r '.allow_insecure_vnc' $OPTIONS_FILE)

echo "[OpenCPN] Starting add-on..."

# Mask password in logs
if [[ -n "$VNC_PASS" && "$VNC_PASS" != "null" ]]; then
    echo "[OpenCPN] VNC Password: ******"
else
    echo "[OpenCPN] VNC Password: <not set>"
fi

echo "[OpenCPN] Insecure VNC: $ALLOW_INSECURE"

# Prepare VNC
mkdir -p ~/.vnc
if [[ -n "$VNC_PASS" && "$VNC_PASS" != "null" ]]; then
    echo "[OpenCPN] Configuring password-protected VNC..."
    (echo "$VNC_PASS" && echo "$VNC_PASS") | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    VNC_ARGS="-rfbauth ~/.vnc/passwd"
elif [[ "$ALLOW_INSECURE" == "true" ]]; then
    echo "[OpenCPN] Starting INSECURE VNC (no password!)"
    VNC_ARGS="-SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
else
    echo "[OpenCPN] ERROR: No VNC password set and insecure mode disabled!"
    echo "Please set a password or enable insecure mode."
    exit 1
fi

# Start XFCE + VNC server
echo "[OpenCPN] Starting TigerVNC on :1"
vncserver :1 -geometry ${VNC_RESOLUTION:-1280x800} -localhost no $VNC_ARGS

# Start noVNC for browser access
echo "[OpenCPN] Starting noVNC on port 6080"
websockify --web=/usr/share/novnc/ 6080 localhost:5901 &

# Launch OpenCPN
echo "[OpenCPN] Launching OpenCPN..."
export DISPLAY=:1
opencpn &

# Keep container alive
tail -f /root/.vnc/*.log
