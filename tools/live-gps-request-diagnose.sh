#!/bin/sh
set -u
printf '=== Requested GPS sources ===\n'
timeout 15 mmcli -m 0 --location-enable-gps-raw --location-enable-gps-nmea
mmcli -m 0 --location-status
printf '=== Logging configuration ===\n'
cat /etc/conf.d/modemmanager 2>/dev/null
ls /var/log
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    if not p.name.isdigit(): continue
    try:
        if (p/'exe').resolve().name=='ModemManager':
            print(p.name,(p/'cmdline').read_bytes().replace(b'\0',b' ').decode())
            for fd in ('1','2'): print('fd'+fd+'='+str((p/'fd'/fd).readlink()))
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
PY
printf 'GPS_REQUEST_DIAGNOSE_END\n'
