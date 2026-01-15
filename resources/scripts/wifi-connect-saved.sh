#!/bin/bash
# WiFi Connect to Saved Network Helper Script for EmulationStation
# This script connects to an already saved WiFi network (no password needed)
# Usage: wifi-connect-saved.sh <connection_name>
# This script needs to be run with sudo privileges

# Ensure root privileges BEFORE any logging to avoid permission issues
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

LOGFILE="/home/ark/wifi-connect.log"
NMCLI_TIMEOUT=30

# Ensure log file is writable by ark user for future non-root access
touch "$LOGFILE" 2>/dev/null
chown ark:ark "$LOGFILE" 2>/dev/null

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log "========================================"
log "wifi-connect-saved.sh started"
log "Executed by user: $(whoami) (UID: $(id -u), EUID: $EUID)"
log "Script path: $0"
log "Arguments count: $#"

CONNECTION_NAME="$1"

if [ -z "$CONNECTION_NAME" ]; then
    log "ERROR: No connection name provided"
    echo "Usage: wifi-connect-saved.sh <connection_name>"
    exit 1
fi

log "Connection name: $CONNECTION_NAME"

# Check if WiFi is enabled
WIFI_STATE=$(nmcli radio wifi 2>/dev/null)
log "Current WiFi state: $WIFI_STATE"

if [ "$WIFI_STATE" != "enabled" ]; then
    log "ERROR: WiFi is not enabled. Enable WiFi first."
    exit 1
fi

# Check for wlan interface
IFACE=$(ip link show 2>/dev/null | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}')
if [ -z "$IFACE" ]; then
    log "ERROR: No wlan interface found"
    exit 1
fi
log "Using interface: $IFACE"

# Check if the connection exists in saved connections
CONNECTION_EXISTS=$(nmcli -t -f name connection show 2>/dev/null | grep -x "$CONNECTION_NAME")
if [ -z "$CONNECTION_EXISTS" ]; then
    log "ERROR: Connection '$CONNECTION_NAME' not found in saved connections"
    exit 1
fi
log "Connection '$CONNECTION_NAME' found in saved connections"

# Get currently active connection on wlan interface
CURRENT_AP=$(iw dev "$IFACE" info 2>/dev/null | grep ssid | cut -c 7-30)
if [ -z "$CURRENT_AP" ]; then
    CURRENT_AP=$(nmcli -t -f name,device connection show --active 2>/dev/null | grep "$IFACE" | cut -d: -f1)
fi
log "Current active connection: ${CURRENT_AP:-none}"

# Check if already connected to the requested network
if [ "$CURRENT_AP" = "$CONNECTION_NAME" ]; then
    log "Already connected to '$CONNECTION_NAME'"
    exit 0
fi

# Disconnect from current network if connected
if [ -n "$CURRENT_AP" ]; then
    log "Disconnecting from current connection '$CURRENT_AP'..."
    nmcli con down "$CURRENT_AP" >> "$LOGFILE" 2>&1
    sleep 1
fi

# Connect to the saved network using nmcli with timeout
log "Connecting to saved network '$CONNECTION_NAME' (timeout: ${NMCLI_TIMEOUT}s)..."

timeout "$NMCLI_TIMEOUT" nmcli con up "$CONNECTION_NAME" 2>&1 | tee -a "$LOGFILE"
RESULT=${PIPESTATUS[0]}

log "nmcli connection up result: $RESULT"

if [ $RESULT -eq 124 ]; then
    log "ERROR: Connection timed out after ${NMCLI_TIMEOUT}s"
    exit 1
elif [ $RESULT -ne 0 ]; then
    log "ERROR: nmcli connection up failed with code $RESULT"
    exit $RESULT
fi

# Verify connection
sleep 2
FINAL_CONNECTED=$(nmcli -t -f name,device connection show --active 2>/dev/null | grep "$IFACE" | cut -d: -f1)
if [ "$FINAL_CONNECTED" = "$CONNECTION_NAME" ]; then
    log "Successfully connected to '$CONNECTION_NAME'"
    log "IP address info:"
    ip addr show "$IFACE" >> "$LOGFILE" 2>&1
    exit 0
else
    log "ERROR: Failed to connect to '$CONNECTION_NAME'. Connected to: '${FINAL_CONNECTED:-none}'"
    exit 1
fi
