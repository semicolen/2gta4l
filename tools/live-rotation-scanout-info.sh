#!/bin/sh
set -eu
mount | grep debug || true
ls -ld /sys/kernel/debug /sys/kernel/debug/dri 2>/dev/null || true
if ! grep -q ' /sys/kernel/debug debugfs ' /proc/mounts; then
    mount -t debugfs debugfs /sys/kernel/debug || true
fi
ls /sys/kernel/debug/dri/0 /sys/kernel/debug/dri/1 2>/dev/null || true
cat /sys/kernel/debug/dri/0/state /sys/kernel/debug/dri/0/framebuffer /sys/kernel/debug/dri/0/summary 2>/dev/null || true
command -v modetest kmsprint || true
echo SCANOUT_INFO_END
