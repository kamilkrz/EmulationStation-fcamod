#!/bin/bash
# WiFi Enable Helper Script for EmulationStation
# This script enables WiFi hardware only - connection is handled by NetworkManager
# This script needs to be run with sudo privileges

# Ensure root privileges BEFORE any logging to avoid permission issues
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

LOGFILE="/home/ark/wifi-enable.log"

# Ensure log file is writable by ark user for future non-root access
touch "$LOGFILE" 2>/dev/null
chown ark:ark "$LOGFILE" 2>/dev/null

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log "========================================"
log "wifi-connect.sh started (enable only)"
log "Executed by user: $(whoami) (UID: $(id -u), EUID: $EUID)"
log "Calling user: ${SUDO_USER:-$(whoami)}"
log "Script path: $0"
log "PWD: $(pwd)"

# Check if wifi is already enabled
log "Checking current wifi state..."
CURRENT_WIFI_STATE=$(nmcli radio wifi 2>/dev/null)
log "Current nmcli radio wifi state: $CURRENT_WIFI_STATE"

# Remove blacklist entries for wifi modules
log "Removing blacklist entries for wifi modules..."
sed -i '/# WIFI-TOGGLE START/,/# WIFI-TOGGLE END/d' /etc/modprobe.d/blacklist.conf 2>&1 | tee -a "$LOGFILE"
sed -i '/^\s*blacklist\s\+8188eu\b/d' /etc/modprobe.d/*.conf 2>&1 | tee -a "$LOGFILE"
sed -i '/^\s*blacklist\s\+r8188eu\b/d' /etc/modprobe.d/*.conf 2>&1 | tee -a "$LOGFILE"

# Re-enable USB WiFi adapter (may have been ejected by disconnect script)
log "Re-enabling USB WiFi adapter..."

# Re-authorize USB host controllers
for usb_host in /sys/bus/usb/devices/usb*; do
    if [ -w "$usb_host/authorized_default" ]; then
        echo 1 > "$usb_host/authorized_default" 2>/dev/null
        log "Set authorized_default=1 for $(basename $usb_host)"
    fi
done

# Trigger USB subsystem rescan via udevadm
log "Triggering udevadm to rescan USB devices..."
udevadm trigger --subsystem-match=usb --action=add 2>&1 | tee -a "$LOGFILE"
udevadm settle --timeout=5 2>&1 | tee -a "$LOGFILE"

# If device 1-1 doesn't exist, try to rescan the USB bus
if [ ! -e "/sys/bus/usb/devices/1-1" ]; then
    log "USB device 1-1 not found, attempting bus rescan..."
    for host in /sys/bus/usb/devices/usb*/; do
        if [ -w "${host}authorized" ]; then
            echo 0 > "${host}authorized" 2>/dev/null
            sleep 0.5
            echo 1 > "${host}authorized" 2>/dev/null
            log "Toggled authorization for $(basename $host)"
        fi
    done
    sleep 2
fi

# Unblock wifi via rfkill
log "Unblocking wifi via rfkill..."
rfkill unblock wifi 2>&1 | tee -a "$LOGFILE"

# Enable wifi radio via nmcli
log "Enabling wifi radio via nmcli..."
nmcli radio wifi on 2>&1 | tee -a "$LOGFILE"

# Load the wifi modules (8188eu or r8188eu for R36S)
log "Loading wifi modules..."
modprobe 8188eu 2>&1 | tee -a "$LOGFILE"
MODPROBE_8188EU=$?
if [ $MODPROBE_8188EU -ne 0 ]; then
    log "8188eu failed, trying r8188eu..."
    modprobe r8188eu 2>&1 | tee -a "$LOGFILE"
fi

# Restart wpa_supplicant
log "Restarting wpa_supplicant..."
systemctl restart wpa_supplicant 2>&1 | tee -a "$LOGFILE"
if [ $? -ne 0 ]; then
    systemctl start wpa_supplicant 2>&1 | tee -a "$LOGFILE"
fi

# Wait for interface to come up
log "Waiting for interface to come up..."
WAIT_COUNT=0
MAX_WAIT=10
IFACE=""
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    IFACE=$(ip link show 2>/dev/null | awk '/wlan[0-9]+:/ {gsub(":", ""); print $2; exit}')
    if [ -n "$IFACE" ]; then
        log "Interface $IFACE found after ${WAIT_COUNT}s"
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    log "Waiting for interface... ${WAIT_COUNT}/${MAX_WAIT}"
done

if [ -z "$IFACE" ]; then
    log "ERROR: No wlan interface found after ${MAX_WAIT}s"
    log "Available network interfaces:"
    ip link show >> "$LOGFILE" 2>&1
    exit 1
fi

# Bring up the wlan interface
log "Bringing up $IFACE interface..."
ip link set "$IFACE" up 2>&1 | tee -a "$LOGFILE"

# Wait for interface to be UP
log "Waiting for interface to be UP..."
WAIT_COUNT=0
MAX_WAIT=5
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if ip link show "$IFACE" 2>/dev/null | grep -q "state UP"; then
        log "Interface $IFACE is UP after ${WAIT_COUNT}s"
        break
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done


log "WiFi hardware enabled successfully"
log "========================================"

exit 0
