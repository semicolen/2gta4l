#!/bin/sh
set -u
echo '=== New network port properties ==='
udevadm info --query=property --path=/sys/class/net/rmnet_ipa0
readlink -f /sys/class/net/rmnet_ipa0/device
cat /usr/lib/udev/rules.d/77-mm-qcom-soc.rules
echo '=== Modem manager after data port appeared ==='
mmcli -L
tail -n 100 /var/log/gta4l/modemmanager-debug.log
echo RMNET_DETECTION_END
