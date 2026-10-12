#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
expected=3ce1942c7ce7656ea7431154e763f65f3172c25d6477b53a47c75987c8f0d5fa
[ "$(boot_hash)" = "$expected" ]
printf '%s\n' 'b89e36eb91eed86326fa94274bdd1af0c0beeff3c1aa195f03e70d733f68cb76  /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r7.apk' | sha256sum -c -
echo '=== State before reboot ==='
uname -a
cat /proc/asound/cards 2>/dev/null || true
for state in /sys/bus/msm_subsys/devices/*/state; do
    printf '%s ' "$state"
    cat "$state"
done
dmesg | grep -Ei 'adsp|alsa|asoc|wsa|codec|panic|BUG:' | tail -n 70
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r7.apk
[ "$(boot_hash)" = "$expected" ]
echo 'Kernel package installed without scripts; existing boot image verified unchanged.'
