#!/bin/sh
set -eu
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
sleep 3
mmcli -m 0 --location-status
mmcli -G INFO
printf 'GPS_CLIENT_STOPPED\n'
