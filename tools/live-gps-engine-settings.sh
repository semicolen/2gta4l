#!/bin/sh
set -eu
qmicli -d qrtr://0 --loc-get-engine-lock || true
qmicli -d qrtr://0 --loc-get-operation-mode || true
qmicli -d qrtr://0 --loc-get-nmea-types || true
mmcli -m 0 --location-status
dmesg | grep -Ei 'gnss|gps|location|mss|modem' | tail -n 25
echo GPS_ENGINE_SETTINGS_END
