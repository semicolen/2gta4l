#!/bin/sh
set -u
echo '=== Recent userspace log ==='
logread | tail -n 200
echo '=== Device services and tools ==='
ls -l /tmp/*strace* /usr/bin/strace /usr/bin/vulkaninfo /dev/subsys_* 2>/dev/null
cat /etc/init.d/polkit
cat /etc/init.d/modemmanager
cat /etc/conf.d/modemmanager
cat /etc/conf.d/postmarketos-zram-swap
cat /sys/block/zram0/comp_algorithm
echo '=== Interfaces and firmware boot ==='
ip -br link
dmesg | grep -Ei 'icnss|wlan|adsp|cdsp|ipa.*fw|pil.*|firmware' | tail -n 160
echo SERVICES_RADIOS_END
