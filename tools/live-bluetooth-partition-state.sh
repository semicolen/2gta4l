#!/bin/sh
set -eu
command -v debugfs || true
for entry in /sys/class/block/mmcblk0p*/uevent; do
    if grep -q '^PARTNAME=sec_efs$' "$entry"; then cat "$entry"; fi
done
cat /sys/class/rfkill/rfkill0/name /sys/class/rfkill/rfkill0/soft
ps | grep '[b]tattach' || true
bluetoothctl list
