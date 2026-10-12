#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,signal
for path in Path('/proc').iterdir():
    if not path.name.isdigit():continue
    try:
        if (path/'comm').read_text().strip()!='python3':continue
        if (path/'wchan').read_text().strip()!='pm_get_wakeup_count':continue
        parent=next(line.split()[1] for line in (path/'status').read_text().splitlines() if line.startswith('PPid:'))
        if b'BATTERY_INVENTORY_END' not in (Path('/proc')/parent/'cmdline').read_bytes():continue
        os.kill(int(path.name),signal.SIGTERM)
        print('Stopped the diagnostic blocked on the wakeup counter: '+path.name)
    except (FileNotFoundError,ProcessLookupError):pass
PY
