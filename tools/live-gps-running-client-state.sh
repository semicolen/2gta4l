#!/bin/sh
set -u
printf '=== Client process ===\n'
pidof where-am-i || true
printf '=== GPS request state ===\n'
mmcli -m 0 --location-status
printf '=== Lock query protocol ===\n'
qmicli --verbose -d qrtr://0 --loc-get-engine-lock 2>&1
printf 'GPS_RUNNING_CLIENT_STATE_END\n'
