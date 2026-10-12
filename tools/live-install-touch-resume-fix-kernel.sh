#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
expected=c5ccb4a8993624bdc84f37e7167406319389c7064e6c52100c5ee3d13de0eb11
[ "$(boot_hash)" = "$expected" ]
printf '%s\n' '3db65e4e36b446479ce69e6f86ffcc7ead183dfabe64f7e791ec6cdb9ae7e039  /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r6.apk' | sha256sum -c -
echo '=== State before reboot ==='
uname -a
cat /proc/asound/cards 2>/dev/null || true
for state in /sys/bus/msm_subsys/devices/*/state; do
    printf '%s ' "$state"
    cat "$state"
done
dmesg | grep -Ei 'adsp|alsa|asoc|wsa|codec|panic|BUG:' | tail -n 70
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r6.apk
[ "$(boot_hash)" = "$expected" ]
echo 'Kernel package installed without scripts; existing boot image verified unchanged.'
