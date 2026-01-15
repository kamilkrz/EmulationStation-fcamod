#!/bin/bash
# WiFi Connect Helper Script for EmulationStation
# This script connects to a specific WiFi network
# Usage: wifi-connect.sh <ssid> [password]
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
log "wifi-connect.sh started"
log "Executed by user: $(whoami) (UID: $(id -u), EUID: $EUID)"
log "Script path: $0"
log "Arguments count: $#"

SSID="$1"
KEY="$2"

if [ -z "$SSID" ]; then
    log "ERROR: No SSID provided"
    echo "Usage: wifi-connect.sh <ssid> [password]"
    exit 1
fi

log "SSID: $SSID"
log "KEY: ${KEY:+(provided, length: ${#KEY})}"

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

# Trigger a rescan
log "Triggering wifi rescan..."
nmcli dev wifi rescan 2>&1 | tee -a "$LOGFILE"

# Wait for scan to complete
sleep 2

# List available networks
log "Available wifi networks:"
nmcli dev wifi list >> "$LOGFILE" 2>&1

# Check if already connected to the requested network
CONNECTED_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes:" | cut -d: -f2)
if [ "$CONNECTED_SSID" = "$SSID" ]; then
    log "Already connected to '$SSID'"
    exit 0
fi

# Disconnect from current network if connected
if [ -n "$CONNECTED_SSID" ]; then
    log "Disconnecting from current network '$CONNECTED_SSID'..."
    nmcli dev disconnect "$IFACE" 2>&1 | tee -a "$LOGFILE"
    sleep 1
fi

# Connect to the network using nmcli with timeout
log "Connecting to network '$SSID' (timeout: ${NMCLI_TIMEOUT}s)..."

if [ -z "$KEY" ]; then
    log "Connecting without password..."
    timeout "$NMCLI_TIMEOUT" nmcli dev wifi connect "$SSID" 2>&1 | tee -a "$LOGFILE"
    RESULT=${PIPESTATUS[0]}
else
    log "Connecting with password..."
    timeout "$NMCLI_TIMEOUT" nmcli dev wifi connect "$SSID" password "$KEY" 2>&1 | tee -a "$LOGFILE"
    RESULT=${PIPESTATUS[0]}
fi

log "nmcli connect result: $RESULT"

if [ $RESULT -eq 124 ]; then
    log "ERROR: Connection timed out after ${NMCLI_TIMEOUT}s"
    exit 1
elif [ $RESULT -ne 0 ]; then
    log "ERROR: nmcli connect failed with code $RESULT"
    exit $RESULT
fi

# Verify connection
sleep 2
FINAL_CONNECTED_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes:" | cut -d: -f2)
if [ "$FINAL_CONNECTED_SSID" = "$SSID" ]; then
    log "Successfully connected to '$SSID'"
    log "IP address info:"
    ip addr show "$IFACE" >> "$LOGFILE" 2>&1
    exit 0
else
    log "ERROR: Failed to connect to '$SSID'. Connected to: '${FINAL_CONNECTED_SSID:-none}'"
    exit 1
fi
