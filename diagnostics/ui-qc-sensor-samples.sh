#!/bin/sh
set -u
echo '=== Direct SSC accelerometer stream ==='
timeout 12 ssccli --sensor=accelerometer --timeout=5 --debug
echo "SSC_EXIT=$?"
echo '=== Current policy after proxy restart ==='
python3 - <<'PY'
from pathlib import Path
import os
for name in ('iio-sensor-proxy','libssc','gnome-shell','mutter'):
    for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        fields=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if fields.get('P')==name:print('PACKAGE',name,fields.get('V'),flush=True)
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or p.stat().st_uid!=10000 or (p/'comm').read_text().strip()!='gnome-shell':continue
        for entry in (p/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=')):
                print(entry.decode(),flush=True)
    except (FileNotFoundError,ProcessLookupError):pass
PY
echo SENSOR_SAMPLES_COMPLETE
