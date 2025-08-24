#!/bin/bash
set -e

# Read password option from Home Assistant config
if [ -n "$VNC_PASSWORD" ]; then
    echo "Setting VNC password..."
    mkdir -p /root/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    vncserver :1 -geometry $VNC_RESOLUTION -rfbauth /root/.vnc/passwd
else
    echo "Starting VNC server WITHOUT password (insecure mode)..."
    vncserver :1 -geometry $VNC_RESOLUTION --I-KNOW-THIS-IS-INSECURE -SecurityTypes None
fi

# Start noVNC
websockify --web=/usr/share/novnc/ --wrap-mode=ignore 0.0.0.0:6080 localhost:5901 &

# Tail logs for Home Assistant add-on
tail -F /root/.vnc/*.log
