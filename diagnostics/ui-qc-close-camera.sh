#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import signal
import time
assert os.getuid()==10000
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and b'/usr/bin/gta4l-camera' in (p/'cmdline').read_bytes().split(b'\0'):
            os.kill(int(p.name),signal.SIGTERM)
            print('Closed test camera window',p.name,flush=True)
    except (FileNotFoundError,ProcessLookupError): pass
time.sleep(2)
PY
