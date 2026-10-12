#!/bin/sh
set -eu
bluetoothctl devices Connected
bluetoothctl devices Paired
echo '=== Mouse input devices ==='
cat /proc/bus/input/devices
echo '=== Bluetooth input support ==='
ls -l /dev/uhid
lsmod | grep -E 'hid|bnep|bluetooth' || true
echo '=== Bluetooth input messages ==='
dmesg | grep -Ei 'rapoo|hid-generic|hidp|Bluetooth: hci0' | tail -n 30
echo MOUSE_CONNECTION_STATE_END
