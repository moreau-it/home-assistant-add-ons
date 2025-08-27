#!/bin/bash
set -e

# Add /usr/local/bin to PATH
export PATH=/usr/local/bin:$PATH

CONFIG_PATH=/data/options.json

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')$*"; }

log "[INFO] Starting OpenCPN Home Assistant Add-on..."
log "[DEBUG] Loading configuration from ${CONFIG_PATH}..."

VNC_PASSWORD=$(jq -r '.vnc_password // empty' "${CONFIG_PATH}")
INSECURE_MODE=$(jq -r '.insecure_mode // false' "${CONFIG_PATH}")

MASKED_PASS=""
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "null" ]; then
    MASKED_PASS="******"
fi
log "[DEBUG] vnc_password='${MASKED_PASS}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}'"

# Start DBus
log "[INFO] Starting DBus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

# Check if kasmvncserver exists in PATH
if ! command -v kasmvncserver >/dev/null 2>&1; then
    log "[ERROR] kasmvncserver not found in PATH!"
    exit 1
fi
log "[DEBUG] Found KasmVNC server at: $(command -v kasmvncserver)"

# Continue with VNC password setup and server start...
