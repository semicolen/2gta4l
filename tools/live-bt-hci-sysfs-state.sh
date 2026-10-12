#!/bin/sh
set -u
cat /var/log/gta4l/bluetooth-bootstrap-test.log
ls -l /sys/class/bluetooth/hci0/ /sys/class/bluetooth/hci0/address 2>/dev/null
bluetoothctl list
rfkill list
dmesg | grep 'Bluetooth:' | tail -n 14
