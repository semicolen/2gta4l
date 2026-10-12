#!/bin/sh
set -eu
ls -l /dev/*rpc* /dev/*dsp* 2>/dev/null || true
for path in /sys/class/adsprpc/* /sys/class/misc/*rpc*; do
    [ -e "$path" ] || continue
    echo "$path"
    udevadm info --query=all --path="$path" || true
done
rc-status default
apk info -v | grep -E 'dbus|gobject|protobuf|qmi|qrtr|gudev|udev|sensor' || true
echo ROTATION_NODE_STATE_END
