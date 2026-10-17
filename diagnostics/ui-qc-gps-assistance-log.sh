#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
paths=[Path('/var/log/messages'),Path('/var/log/ModemManager.log'),Path('/var/log/rc.log')]
paths+=list(Path('/var/log/gta4l').rglob('*modemmanager*.log'))
phrases=('supported assistance','predicted orbits data source','Preparing SM-T505 GPS engine','LOC engine-lock completion')
for path in paths:
    if not path.is_file():continue
    with path.open('rb') as source:
        source.seek(max(0,path.stat().st_size-2*1024*1024))
        lines=source.read().decode(errors='replace').splitlines()
    selected=[line for line in lines if any(phrase in line for phrase in phrases)]
    if selected:print('ASSISTANCE_LOG',path,'\n'+'\n'.join(selected[-12:]),flush=True)
PY
