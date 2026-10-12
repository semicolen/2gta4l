#!/bin/sh
set -u
umask 077
printf '=== Previous MMCLI error, if present ===\n'
grep '^error:' /var/log/gta4l/gps-private/location.json || true
printf '=== MMCLI output format support ===\n'
mmcli --help-all | grep -E 'json|location-get|logging'
printf '=== Raw fix check ===\n'
mmcli -m 0 --location-get-gps-raw -J > /var/log/gta4l/gps-private/raw.json 2>&1
printf 'raw exit=%s\n' "$?"
grep '^error:' /var/log/gta4l/gps-private/raw.json || true
printf '=== NMEA check ===\n'
mmcli -m 0 --location-get-gps-nmea -J > /var/log/gta4l/gps-private/nmea.json 2>&1
printf 'nmea exit=%s\n' "$?"
grep '^error:' /var/log/gta4l/gps-private/nmea.json || true
python3 - <<'PY'
import json
from pathlib import Path
for name in ('raw','nmea'):
    try:
        v=json.loads(Path('/var/log/gta4l/gps-private/'+name+'.json').read_text())
        print(name+' JSON decoded')
        def inspect(v,prefix=''):
            if isinstance(v,dict):
                for k,x in v.items(): inspect(x,prefix+'.'+k)
            elif isinstance(v,list): print(prefix+' count='+str(len(v)))
            else: print(prefix+' populated='+str(v not in (None,'','--')))
        inspect(v)
    except Exception as e: print(name+' '+type(e).__name__)
PY
printf '=== QMI NMEA indication test ===\n'
timeout -k 2 8 qmicli -d qrtr://0 --loc-follow-nmea > /var/log/gta4l/gps-private/nmea-follow.log 2>&1 || true
printf 'NMEA log bytes: '; wc -c < /var/log/gta4l/gps-private/nmea-follow.log
printf 'NMEA sentences: '; grep -c '\$G' /var/log/gta4l/gps-private/nmea-follow.log || true
printf 'GPS_DATA_CHECK_END\n'
