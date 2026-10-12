#!/bin/sh
set -eu
udevadm info --query=all --name=/dev/adsprpc-smd
cat /sys/dev/char/499:0/uevent
readlink -f /sys/dev/char/499:0
echo ROTATION_RPC_UDEV_END
