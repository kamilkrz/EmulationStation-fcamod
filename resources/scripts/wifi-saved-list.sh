#!/bin/bash
# WiFi Saved Connections List Helper Script for EmulationStation
# This script lists all saved WiFi connections
# Usage: wifi-saved-list.sh
# Output: One connection name per line

# List all saved WiFi connections (type 802-11-wireless)
# Using nmcli to get connection names that are wifi type
nmcli -t -f name,type connection show 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1
