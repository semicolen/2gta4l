#!/bin/sh
set -u
echo '=== WLAN activation ==='
cat /var/log/gta4l/wlan-tqftp-start.log
echo '=== Interfaces ==='
ip -br link
iw dev 2>/dev/null
echo '=== Recent WLAN startup log ==='
dmesg | grep -Ei 'icnss|cnss|wlfw|wlan|wcss|wifi|wcnss|qdf|qcacld|vos|hdd' | tail -n 160
echo WLAN_ACTIVATION_RESULT_END
