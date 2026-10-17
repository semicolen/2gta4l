#!/bin/sh
set -u
echo UTC_CLOCK
date -u '+%Y-%m-%dT%H:%M:%SZ'
echo LOC_COMMANDS
qmicli --help-loc | grep -Ei 'predicted|time|assistance|server|mode|lock|position'
echo PREDICTED_ORBIT_SOURCE
timeout 15 qmicli -d qrtr://0 --loc-get-predicted-orbits-data-source
echo OPERATION_MODE
timeout 15 qmicli -d qrtr://0 --loc-get-operation-mode
echo MM_LOCATION_CONFIGURATION
mmcli -m 0 --location-status
echo GPS_ASSISTANCE_INVENTORY_COMPLETE
