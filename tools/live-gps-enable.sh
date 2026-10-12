#!/bin/sh
set -eu
mmcli -m 0 --location-set-gps-refresh-rate=2
mmcli -m 0 --location-enable-gps-raw --location-enable-gps-nmea
mmcli -m 0 --location-status
sleep 4
mmcli -m 0 --location-get || true
tail -n 30 /var/log/gta4l/modemmanager.log 2>/dev/null || true
echo GPS_INITIAL_ENABLE_END
