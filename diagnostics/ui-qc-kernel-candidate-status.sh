#!/bin/sh
set -eu
echo BOOT_ID
cat /proc/sys/kernel/random/boot_id
uname -a
uptime
echo BATTERY
cat /sys/class/power_supply/battery/capacity
echo UPLOAD_FILES
ls -lh /tmp/gta4l-upload 2>/dev/null || true
echo KERNEL_PACKAGE
apk --no-network info -v linux-samsung-gta4l
echo MEMORY_AND_TMP
grep -E 'MemAvailable|MemFree' /proc/meminfo
df -h /tmp
echo PSTORE
ls -l /sys/fs/pstore
echo REBOOT_ERRORS
dmesg | grep -Ei 'panic|BUG:|Unable to handle|gpu fault|kgsl.*fault|watchdog.*bite|Boot reason|bootreason' | tail -n 15 || true
