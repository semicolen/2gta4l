#!/bin/sh
set -u
printf '=== Request GPS engine available for local testing ===\n'
timeout 8 qmicli --verbose -d qrtr://0 --loc-set-engine-lock=none 2>&1
printf '=== Read lock setting after request ===\n'
timeout 8 qmicli --verbose -d qrtr://0 --loc-get-engine-lock 2>&1
printf '=== ModemManager GPS start ===\n'
timeout 10 mmcli -m 0 --location-enable-gps-raw --location-enable-gps-nmea
mmcli -m 0 --location-status
printf 'GPS_UNLOCK_TEST_END\n'
