#!/bin/sh
set -eu
[ ! -e /run/gta4l-bt-test.pid ]
umask 077
nohup python3 /tmp/gta4l-upload/gta4l-bt-initialize.py > /var/log/gta4l/bluetooth-bootstrap-test.log 2>&1 </dev/null &
echo "$!" > /run/gta4l-bt-test.pid
sleep 8
cat /var/log/gta4l/bluetooth-bootstrap-test.log
grep -q BT_HCI_CONTROLLER_READY /var/log/gta4l/bluetooth-bootstrap-test.log
bluetoothctl list
echo BT_STAGED_CONTROLLER_START_END
