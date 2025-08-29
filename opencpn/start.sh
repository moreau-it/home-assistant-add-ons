#!/bin/bash
set -Eeuo pipefail

# -------- Config & defaults --------
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"

CONFIG_PATH="/data/options.json"

# Defaults (can be overridden by ENV or options.json)
DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1280x800}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
KASMVNC_EXTRA_ARGS="${KASMVNC_EXTRA_ARGS:-}"   # optional extra flags to kasmvncserver

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

jq_get() {
  local key="$1" default="${2:-}"
  if [[ -f "$CONFIG_PATH" ]]; then
    local val
    val="$(jq -r "$key // empty" "$CONFIG_PATH" 2>/dev/null || true)"
    if [[ -n "$val" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "$default"
}

log "[INFO] Starting OpenCPN Home Assistant add-on"
log "[DEBUG] Loading configuration from ${CONFIG_PATH}"

# Read config (with ENV fallbacks)
VNC_PASSWORD="${VNC_PASSWORD:-$(jq_get '.vnc_password' '')}"
INSECURE_MODE_RAW="${INSECURE_MODE:-$(jq_get '.insecure_mode' 'false')}"
INSECURE_MODE="$(echo "$INSECURE_MODE_RAW" | tr '[:upper:]' '[:lower:]')"

MASKED_PASS=""
if [[ -n "${VNC_PASSWORD:-}" ]]; then MASKED_PASS="******"; fi
log "[DEBUG] display='${DISPLAY}'"
log "[DEBUG] vnc_resolution='${VNC_RESOLUTION}', vnc_port='${VNC_PORT}', novnc_port='${NOVNC_PORT}'"
log "[DEBUG] insecure_mode='${INSECURE_MODE}', vnc_password='${MASKED_PASS}'"

# -------- DBus --------
log "[INFO] Ensuring DBus is running..."
mkdir -p /var/run/dbus
if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
  dbus-daemon --system --fork
fi

# -------- Sanity checks --------
if ! command -v kasmvncserver >/dev/null 2>&1; then
  log "[ERROR] 'kasmvncserver' not found in PATH! Aborting."
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  log "[WARN] 'jq' not found; options.json parsing may be limited."
fi

# -------- VNC password handling --------
VNC_ARGS=(":${DISPLAY#:}" "-geometry" "${VNC_RESOLUTION}")

if [[ "$INSECURE_MODE" == "true" ]]; then
  log "[INFO] INSECURE mode enabled (no auth)."
  VNC_ARGS+=("-SecurityTypes" "None" "--I-KNOW-THIS-IS-INSECURE")
else
  if [[ -z "${VNC_PASSWORD:-}" ]]; then
    log "[ERROR] VNC password not set! Either enable insecure_mode or provide vnc_password."
    exit 1
  fi
  log "[INFO] Setting VNC password for user 'root'..."
  mkdir -p /root/.vnc
  # Write explicitly to /root/.kasmpasswd (KasmVNC's default location)
  printf '%s\n%s\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | kasmvncpasswd -u root /root/.kasmpasswd
  chmod 600 /root/.kasmpasswd || true
  # KasmVNC uses HTTP Basic Auth backed by ~/.kasmpasswd; -rfbauth is not required
fi

# Optional: honor VNC_PORT if kasmvncserver supports -rfbport (default is 5900 + display)
# If you want to force the port explicitly, uncomment the next two lines:
# VNC_ARGS+=("-rfbport" "${VNC_PORT}")
# export VNC_PORT  # used later by websockify

# Extra args passthrough (if any)
if [[ -n "${KASMVNC_EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA=(${KASMVNC_EXTRA_ARGS})
  VNC_ARGS+=("${EXTRA[@]}")
fi

# -------- Start KasmVNC --------
log "[INFO] Starting KasmVNC on display '${DISPLAY}'..."
# Kill any stale server for this display
kasmvncserver --kill "${DISPLAY}" >/dev/null 2>&1 || true
kasmvncserver "${VNC_ARGS[@]}"

# -------- Start XFCE session --------
export DISPLAY
log "[INFO] Launching XFCE desktop..."
startxfce4 >/root/.vnc/xfce.log 2>&1 &

# -------- Start noVNC if available --------
# We expect novnc at /usr/share/novnc and websockify in PATH (from novnc or websockify pkg).
if command -v websockify >/dev/null 2>&1 && [[ -d "/usr/share/novnc" ]]; then
  log "[INFO] Starting noVNC on port ${NOVNC_PORT} (proxying to ${VNC_PORT})..."
  # If VNC_PORT isn't explicitly set, derive from display (5900 + N)
  if [[ -z "${VNC_PORT:-}" ]]; then
    VNC_PORT="$((5900 + ${DISPLAY#:}))"
  fi
  websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}" \
    >/root/.vnc/novnc.log 2>&1 &
else
  log "[WARN] noVNC not started (websockify and/or /usr/share/novnc missing)."
fi

# -------- Start OpenCPN --------
if command -v opencpn >/dev/null 2>&1; then
  log "[INFO] Launching OpenCPN..."
  opencpn >/root/.vnc/opencpn.log 2>&1 &
else
  log "[ERROR] 'opencpn' not found in PATH."
fi

# -------- Tailing logs to keep container in foreground --------
log "[INFO] Services started. Tailing VNC logs..."
# Tail whatever logs are available; fall back to infinite sleep
shopt -s nullglob
LOG_FILES=(/root/.vnc/*.log)
if (( ${#LOG_FILES[@]} > 0 )); then
  tail -F "${LOG_FILES[@]}"
else
  log "[WARN] No log files found to tail; sleeping."
  sleep infinity
fi
