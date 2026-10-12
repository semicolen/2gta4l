#!/bin/sh
set -u
uname -a
echo '=== WLAN devices ==='
ip -br link
ls -l /dev/wlan /sys/bus/platform/drivers/icnss* 2>/dev/null
echo '=== WLAN kernel state ==='
dmesg | grep -Ei 'icnss|cnss|wlfw|wlan|wcss|wifi|wcnss|wlan_pd' | tail -n 100
echo '=== QMI service list ==='
timeout 5 qrtr-lookup 2>/dev/null || true
echo '=== WLAN parameters ==='
for value in /sys/module/icnss*/parameters/* /sys/module/wlan/parameters/*; do
    [ -f "$value" ] || continue
    printf '%s: ' "$value"
    head -c 512 "$value"
    echo
done
echo WLAN_SUMMARY_END
