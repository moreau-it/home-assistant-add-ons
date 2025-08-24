#!/bin/bash
set -e

echo "[INFO] Starting OpenCPN Home Assistant Add-on..."

# Ensure .Xauthority exists to prevent GTK+ crashes
if [ ! -f /root/.Xauthority ]; then
    touch /root/.Xauthority
    xauth generate :1 . trusted
fi

# Configure VNC password or insecure mode
if [ -n "$VNC_PASSWORD" ]; then
    echo "[INFO] Setting VNC password..."
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    vncserver :1 -geometry $VNC_RESOLUTION -rfbauth /root/.vnc/passwd
else
    echo "[WARNING] Starting VNC in INSECURE MODE!"
    vncserver :1 -geometry $VNC_RESOLUTION --I-KNOW-THIS-IS-INSECURE -SecurityTypes None
fi

# Start noVNC in background
echo "[INFO] Starting noVNC on port 6080..."
websockify --web=/usr/share/novnc/ --wrap-mode=ignore 0.0.0.0:6080 localhost:5901 &

# Start XFCE desktop
echo "[INFO] Starting XFCE4 desktop..."
startxfce4 &

# Wait for XFCE to initialize
sleep 3

# Start OpenCPN GUI
echo "[INFO] Launching OpenCPN..."
opencpn &

# Keep container running
tail -F /root/.vnc/*.log
