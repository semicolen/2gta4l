#!/bin/sh
set -u
umask 077
mkdir -p /var/log/gta4l/gps-private
mmcli -m 0 --location-get --output-json > /var/log/gta4l/gps-private/location.json 2>&1
python3 - <<'PY'
import json
from pathlib import Path
p=Path('/var/log/gta4l/gps-private/location.json')
try:
    value=json.loads(p.read_text())
    def inspect(v, prefix=''):
        if isinstance(v, dict):
            for k,x in v.items(): inspect(x, prefix+'.'+k)
        elif isinstance(v, list):
            print(prefix+' count='+str(len(v)))
        else:
            print(prefix+' populated='+str(v not in (None,'','--')))
    inspect(value)
except Exception as e:
    print('Location result was not JSON:', type(e).__name__)
PY
printf '=== Satellite reception ===\n'
timeout 20 qmicli -d qrtr://0 --loc-follow-gnss-sv-info 2>&1 || true
printf '=== GPS enabled state ===\n'
mmcli -m 0 --location-status
printf 'GPS_OBSERVE_END\n'
