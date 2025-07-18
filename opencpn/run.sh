#!/usr/bin/env bash
set -e

echo "[INFO] Starting Xvfb..."
Xvfb :0 -screen 0 1024x768x16 &
sleep 2

echo "[INFO] Starting Fluxbox..."
fluxbox &

echo "[INFO] Starting x11vnc..."
x11vnc -display :0 -forever -nopw -shared -bg

echo "[INFO] Starting noVNC web proxy..."
websockify --web=/usr/share/novnc/ 6080 localhost:5900 &

echo "[INFO] Starting OpenCPN..."
opencpn || {
  echo "[ERROR] OpenCPN failed to start, entering debug loop..."
  tail -f /dev/null
}
