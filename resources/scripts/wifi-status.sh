#!/bin/bash
# WiFi Status Helper Script for EmulationStation
# Returns: OFF, ON, CONNECTING, or CONNECTED

echo "[wifi-status.sh] Executed by user: $(whoami) (UID: $(id -u))" >&2

# Check if rfkill shows wifi as blocked
if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    echo "OFF"
    exit 0
fi

# Check if wlan interface exists
IFACE=$(ip link show 2>/dev/null | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}')

if [ -z "$IFACE" ]; then
    echo "OFF"
    exit 0
fi

# Check if connected via nmcli
if nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep -qE "^${IFACE}:connected$"; then
    echo "CONNECTED"
    exit 0
fi

# Check if interface is UP (connecting)
if ip link show "$IFACE" 2>/dev/null | grep -q "state UP"; then
    echo "CONNECTING"
    exit 0
fi

echo "ON"
exit 0
