#!/bin/sh
set -eu
for attempt in $(seq 1 16); do
    if mmcli -m 0 --location-status 2>/dev/null; then
        printf 'MODEM_LOCATION_INTERFACE_READY\n'
        exit 0
    fi
    sleep 2
done
printf 'Modem location interface is not ready yet\n' >&2
exit 1
