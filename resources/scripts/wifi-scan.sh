#!/bin/bash
# WiFi Scan Helper Script for EmulationStation
# This script needs to be run with sudo privileges

echo "[wifi-scan] Executed by user: $(whoami) (UID: $(id -u))" >&2

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# Trigger a rescan
nmcli dev wifi rescan 2>/dev/null
sleep 2

# List available networks (SSID only, unique, non-empty)
nmcli -t -f SSID dev wifi list 2>/dev/null | grep -v '^$' | sort -u
