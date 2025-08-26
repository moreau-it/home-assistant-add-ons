#!/bin/bash
set -e

# Set a VNC password non-interactively (not logged)
echo "Setting VNC password..."
mkdir -p /root/.vnc
x11vnc -storepasswd "${VNC_PASSWORD:-opencpn}" /root/.vnc/passwd >/dev/null 2>&1

# Start VNC server
tigervncserver ${DISPLAY} -geometry ${VNC_RESOLUTION} -SecurityTypes VncAuth -passwd /root/.vnc/passwd

# Start noVNC
websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT} &

# Launch OpenCPN after XFCE starts
sleep 3
opencpn &

# Keep foreground
tail -f /dev/null
