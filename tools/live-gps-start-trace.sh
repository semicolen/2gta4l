#!/bin/sh
set -u
printf '=== GPS engine lock query ===\n'
timeout 8 qmicli --verbose -d qrtr://0 --loc-get-engine-lock 2>&1
printf '=== Direct standalone start ===\n'
timeout 12 qmicli --verbose -d qrtr://0 --loc-start --loc-session-id=17 2>&1
printf '=== Service logging configuration ===\n'
cat /etc/init.d/modemmanager /etc/conf.d/modemmanager 2>/dev/null
printf '=== Location status ===\n'
mmcli -m 0 --location-status
printf 'GPS_START_TRACE_END\n'
