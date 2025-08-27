#!/bin/bash
# start.sh

LOGFILE=/data/openocpn.log
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Add timestamp header
echo "################${DATE}################" >> "$LOGFILE"

# Print PATH
echo "[DEBUG] Current PATH: $PATH" >> "$LOGFILE"

# Check if kasmvncserver exists
KASM_PATH=$(command -v kasmvncserver || true)
if [ -z "$KASM_PATH" ]; then
    echo "[ERROR] kasmvncserver not found in PATH!" >> "$LOGFILE"
else
    echo "[DEBUG] kasmvncserver found at: $KASM_PATH" >> "$LOGFILE"
fi

# Your existing startup commands
echo "[INFO] Starting OpenCPN Home Assistant Add-on..." >> "$LOGFILE"
echo "[INFO] Starting DBus..." >> "$LOGFILE"
# ... rest of your script
