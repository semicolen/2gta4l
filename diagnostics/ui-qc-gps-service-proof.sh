#!/bin/sh
set -eu
rc-service gta4l-gps-assistance status
tail -n 15 /var/log/gta4l/gps-private/assistance.log
python3 - <<'PY'
from pathlib import Path
import json,time
p=Path('/var/cache/gta4l-gps-assistance')
for f in sorted(p.iterdir()):
    print('ASSISTANCE_CACHE',f.name,'bytes',f.stat().st_size,'age_seconds',round(time.time()-f.stat().st_mtime),'mode',oct(f.stat().st_mode&0o777))
PY
timeout 15 qmicli -d qrtr://0 --loc-get-predicted-orbits-data-validity
