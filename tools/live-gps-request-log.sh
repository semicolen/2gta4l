#!/bin/sh
set -eu
printf '=== GPS request markers ===\n'
for log in /var/log/messages /var/log/ModemManager.log; do
    if [ -f "$log" ]; then
        grep -E 'Preparing SM-T505 GPS engine|GPS engine|LOC start|GPS location gathering' "$log" | tail -n 30 || true
    fi
done
printf '=== Supervised modem and desktop ===\n'
rc-service modemmanager status
mmcli -m 0 --location-status
pidof xfce4-session
printf 'GPS_REQUEST_LOG_END\n'
