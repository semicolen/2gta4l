#!/bin/sh
set -eu
mmcli -L
mmcli -m 0 --location-status || true
qmicli --help-loc
qrtr-lookup 16 || true
command -v gpsd gpspipe gclue || true
apk list --installed modemmanager libqmi gpsd geoclue
echo GPS_CAPABILITIES_END
