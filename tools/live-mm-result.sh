#!/bin/sh
set -u
mmcli -L
tail -n 130 /var/log/gta4l/modemmanager-debug.log
cat /var/log/gta4l/modemmanager-launch.log
echo MM_RESULT_END
