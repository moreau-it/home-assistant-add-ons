#!/usr/bin/env bash

# Start virtual display
Xvfb :0 -screen 0 1024x768x16 &
sleep 2

# Start lightweight window manager
fluxbox &

# Start VNC backend
x11vnc -display :0 -forever -nopw &

# Start noVNC proxy (serves to port 6080)
websockify --web=/usr/share/novnc/ 6080 localhost:5900 &

# Start OpenCPN GUI
opencpn
