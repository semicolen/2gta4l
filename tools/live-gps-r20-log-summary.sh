#!/bin/sh
set -u
printf '=== Direct LOC preparation diagnostics (coordinates excluded) ===\n'
log=/var/log/gta4l/gps-private/modemmanager-direct.log
if [ -f "$log" ]; then
    chmod 600 "$log"
    grep -E 'Preparing SM-T505 GPS engine|Couldn.t prepare SM-T505|Couldn.t start GPS engine|LOC engine-lock completion|Couldn.t find any PDS/LOC client' "$log" | tail -n 20
fi
mmcli -m 0 --location-status
printf 'GPS_DIRECT_LOG_SUMMARY_END\n'
