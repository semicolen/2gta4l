#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import re
folder=Path('/home/tablet/.cache/gta4l-gps')
for name in ('agent.log','where-am-i.log'):
    p=folder/name
    text=p.read_text(errors='replace') if p.exists() else ''
    print(name+' bytes='+str(len(text)))
    print(name+' latitude_present='+str(bool(re.search(r'Latitude:\s*[-+0-9]',text))))
    print(name+' longitude_present='+str(bool(re.search(r'Longitude:\s*[-+0-9]',text))))
    seen=set()
    for line in text.splitlines():
        if re.search(r'Accuracy:|Altitude:|Timeout|Failed|ERROR|CRITICAL|WARNING|not authorized',line):
            item='Altitude present' if 'Altitude:' in line else line
            if item not in seen: print(item); seen.add(item)
PY
printf '=== Current GPS ownership ===\n'
mmcli -m 0 --location-status
printf 'GEOCLUE_TEST_SUMMARY_END\n'
