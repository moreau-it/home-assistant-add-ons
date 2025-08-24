#!/bin/bash
set -e

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."

mkdir -p /root/.vnc

if [ -n "$VNC_PASSWORD" ]; then
    echo "[INFO] Secured VNC mode enabled."
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    vncserver :1 -geometry $VNC_RESOLUTION -rfbauth /root/.vnc/passwd
else
    if [ "$INSECURE_MODE" = "true" ]; then
        echo "[WARNING] Starting VNC in INSECURE MODE!"
        vncserver :1 -geometry $VNC_RESOLUTION --I-KNOW-THIS-IS-INSECURE -SecurityTypes None
    else
        echo "[ERROR] No VNC password set! Enable insecure mode in config or add a password."
        exit 1
    fi
fi

# Wait until X server is up
for i in $(seq 1 10); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "[INFO] X server is ready."
        break
    fi
    echo "[INFO] Waiting for X server..."
    sleep 1
done

# Generate .Xauthority once X11 is ready
if [ ! -f /root/.Xauthority ]; then
    touch /root/.Xauthority
    xauth generate :1 . trusted || true
    echo "[INFO] Xauthority generated for display :1"
fi

# Start XFCE desktop environment
echo "[INFO] Starting XFCE4 desktop..."
startxfce4 &

# Start noVNC in background
echo "[INFO] Starting noVNC on port 6080..."
websockify --web=/usr/share/novnc/ --wrap-mode=ignore 0.0.0.0:6080 localhost:5901 &

# Launch OpenCPN
sleep 3
echo "[INFO] Launching OpenCPN..."
opencpn &

# Keep container alive
tail -F /root/.vnc/*.log
