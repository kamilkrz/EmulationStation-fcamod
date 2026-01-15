#!/bin/bash
# WiFi Disconnect Helper Script for EmulationStation
# This script needs to be run with sudo privileges
# Debug version with extensive logging

LOGFILE="/home/ark/wifi-disconnect.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log "========================================"
log "wifi-disconnect.sh started"
log "Executed by user: $(whoami) (UID: $(id -u), EUID: $EUID)"
log "Calling user: ${SUDO_USER:-$(whoami)}"
log "Script path: $0"
log "Arguments: $*"
log "PWD: $(pwd)"

# Ensure root privileges
if [ "$(id -u)" -ne 0 ]; then
    log "Not running as root, escalating with sudo..."
    exec sudo -- "$0" "$@"
fi

log "Running as root, proceeding with disconnect"

# Wi-Fi module detection
log "Starting WiFi module detection..."

# Method 1: Find the driver currently bound to any 'wlan' interface
MODULES_FROM_SYS=$(basename -a $(readlink /sys/class/net/wlan*/device/driver/module 2>/dev/null) 2>/dev/null)

# Method 2: Identify all loaded modules that depend on the wireless stack (cfg80211)
MODULES_FROM_STACK=$(lsmod | grep "^cfg80211" | awk '{print $4}' | tr ',' ' ')

# Combine both methods and remove duplicates
DETECTED_MODULES=$(echo "$MODULES_FROM_SYS $MODULES_FROM_STACK" | tr ' ' '\n' | sort -u | grep -v "cfg80211" | grep -v "mac80211" | xargs)

if [ -z "$DETECTED_MODULES" ]; then
    log "INFO: No WiFi modules identified."
else
    log "Identified WiFi modules: $DETECTED_MODULES"
fi

# Releasing the IP address before disconnecting
log "Releasing IP address..."
dhclient -r $IFACE 2>&1 | tee -a "$LOGFILE" 

# Disconnect the Wi-Fi
log "Disconnecting Wi-Fi..."
nmcli dev disconnect iface $IFACE 2>&1 | tee -a "$LOGFILE"

# Blocking Wi-Fi via rfkill
log "Blocking wifi via rfkill..."
rfkill list wifi >> "$LOGFILE" 2>&1
log "rfkill list before block (above)"
rfkill block wifi 2>&1 | tee -a "$LOGFILE"
log "rfkill block result: $?"

# Disable wifi radio via nmcli
log "Disabling wifi radio via nmcli..."
nmcli radio wifi off 2>&1 | tee -a "$LOGFILE"
log "nmcli radio wifi off result: $?"

# Stop wpa_supplicant
log "Stopping wpa_supplicant..."
systemctl stop wpa_supplicant 2>&1 | tee -a "$LOGFILE"
log "wpa_supplicant stop result: $?"

# Unload wifi modules
log "Unloading wifi modules..."
if [ ! -z "$DETECTED_MODULES" ]; then
    log "Unloading detected modules: $DETECTED_MODULES"
    for mod in $DETECTED_MODULES; do
        modprobe -r "$mod" 2>&1 | tee -a "$LOGFILE"
        log "modprobe -r $mod result: $?"
    done
fi

# Add blacklist entries to prevent auto-loading
log "Current blacklist.conf content:"
cat /etc/modprobe.d/blacklist.conf >> "$LOGFILE" 2>&1
if [ ! -z "$DETECTED_MODULES" ]; then
    log "Updating /etc/modprobe.d/blacklist.conf..."
    {
        echo "# WIFI-TOGGLE START ($(date))"
        for mod in $DETECTED_MODULES; do
            echo "blacklist $mod"
        done
        echo "# WIFI-TOGGLE END"
    } >> /etc/modprobe.d/blacklist.conf
    log "Blacklist entries added for: $DETECTED_MODULES"
fi

# Eject the USB wifi device to free the port for OTG
log "Ejecting USB wifi device (1-1)..."
log "USB devices before eject:"
ls -la /sys/bus/usb/devices/ >> "$LOGFILE" 2>&1
if [ -e "/sys/bus/usb/devices/1-1" ]; then
    echo 1 > /sys/bus/usb/devices/1-1/remove 2>&1 | tee -a "$LOGFILE"
    log "USB eject result: $?"
else
    log "USB device 1-1 not found, skipping eject."
fi

# Reconfigure USB for OTG mode
log "Reconfiguring USB for OTG mode..."
echo 1 > /sys/module/usbcore/parameters/old_scheme_first 2>&1 | tee -a "$LOGFILE"
log "OTG reconfiguration complete."
log "OTG reconfigure result: $?"

log "wifi-disconnect.sh finished"
log "========================================"

exit 0
