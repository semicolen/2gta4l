#!/bin/sh
set -u
cat /var/log/gta4l/bluetooth-bootstrap-test.log
bluetoothctl list
bluetoothctl show
rfkill list
ps | grep -E '[b]tattach|[g]ta4l-bt-initialize'
dmesg | grep -E 'Bluetooth:|bt_power|bt_vreg|ttyHS0' | tail -n 40
