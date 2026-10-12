#!/bin/sh
set -eu
printf '=== Consent test result ===\n'
cat /run/gta4l-gps-agent-check/result.json
printf '=== Idle GPS state ===\n'
mmcli -m 0 --location-status
printf '=== Test process state ===\n'
pidof where-am-i || true
printf '=== GPS startup configuration ===\n'
rc-service gta4l-gps-prepare status
cat /run/gta4l-gps-ready
printf 'GPS_BEFORE_REBOOT_END\n'
