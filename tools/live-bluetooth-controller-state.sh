#!/bin/sh
set -u
echo '=== Bluetooth daemon and controller ==='
rc-service bluetooth status
bluetoothctl list
ls -l /dev/ttyHS* /dev/ttyMSM* /dev/btpower 2>/dev/null
command -v btattach || true
command -v hciattach || true
echo '=== Radio power ==='
rfkill list
echo '=== Bluetooth device tree ==='
find /sys/firmware/devicetree/base -type d | grep -Ei 'bluetooth|bt[_-]|uart' | head -n 40
echo '=== Bluetooth firmware names ==='
find /lib/firmware/postmarketos -type f | grep -Ei 'btfw|btnv|rampatch|nvm.*tlv|bluetooth' | head -n 50
echo '=== Bluetooth kernel messages ==='
dmesg | grep -Ei 'bluetooth|bt_power|ttyHS|uart.*(probe|error)' | head -n 70
echo BLUETOOTH_CONTROLLER_STATE_END
