#!/bin/sh
set -eu
mmcli -m 0 --location-disable-gps-raw --location-disable-gps-nmea
# Restore the same lock seen immediately after the normal reboot. The desktop
# test must clear it through the new request path, without a manual unlock.
qmicli -d qrtr://0 --loc-set-engine-lock=mt
mmcli -m 0 --location-status
printf 'GPS_IDLE_FOR_POST_LOGIN_TEST\n'
