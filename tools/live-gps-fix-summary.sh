#!/bin/sh
set -eu
umask 077
mmcli -m 0 --location-get -J > /var/log/gta4l/gps-private/location.json
python3 - <<'PY'
import json
from pathlib import Path
v=json.loads(Path('/var/log/gta4l/gps-private/location.json').read_text())
def inspect(v,prefix=''):
    if isinstance(v,dict):
        for k,x in v.items(): inspect(x,prefix+'.'+k)
    elif isinstance(v,list): print(prefix+' count='+str(len(v)))
    else: print(prefix+' populated='+str(v not in (None,'','--')))
inspect(v)
PY
printf 'GPS_FIX_SUMMARY_END\n'
