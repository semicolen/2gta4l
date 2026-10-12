#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
expected=a884496fd71c677165ec2ef3bcb60b1125108919be748814db40c6aaebbbeadb
[ "$(boot_hash)" = "$expected" ]
printf '%s\n' 'df8c272acda221827fe63c602a05f5dbd6e01505fb0e792bb44d3a5c0acde331  /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r5.apk' | sha256sum -c -
echo '=== State before reboot ==='
uname -a
cat /proc/asound/cards 2>/dev/null || true
for state in /sys/bus/msm_subsys/devices/*/state; do
    printf '%s ' "$state"
    cat "$state"
done
dmesg | grep -Ei 'adsp|alsa|asoc|wsa|codec|panic|BUG:' | tail -n 70
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r5.apk
[ "$(boot_hash)" = "$expected" ]
echo 'Kernel package installed without scripts; existing boot image verified unchanged.'
