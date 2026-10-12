#!/bin/sh
set -u
echo '=== Firmware requests ==='
tail -c 48000 /var/log/gta4l/tqftpserv.log 2>/dev/null
echo '=== Firmware readiness ==='
dmesg | grep -Ei 'icnss|cnss|wlfw|wlan|wcss|wifi|wcnss|wlan_pd' | tail -n 80
timeout 5 qrtr-lookup 2>/dev/null || true
ip -br link
echo TQFTP_LOG_READ_END
