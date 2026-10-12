#!/bin/sh
set -eu
printf '=== GPS state before controlled regression ===\n'
test -f /etc/ModemManager/gta4l-gps-unlock
mmcli -m 0 --location-status
python3 - <<'PY'
from pathlib import Path
import os
import signal
for entry in Path('/proc').iterdir():
    if not entry.name.isdigit(): continue
    try:
        if str((entry/'exe').resolve())=='/usr/libexec/geoclue-2.0/demos/where-am-i':
            os.kill(int(entry.name),signal.SIGTERM)
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
PY
sleep 2
mmcli -m 0 --location-disable-gps-nmea --location-disable-gps-raw
printf '=== Apply temporary engine lock for request-path test ===\n'
qmicli -d qrtr://0 --loc-set-engine-lock=all
qmicli --verbose -d qrtr://0 --loc-get-engine-lock 2>&1 || true
mmcli -G DEBUG
printf 'GPS_REQUEST_REGRESSION_READY\n'
