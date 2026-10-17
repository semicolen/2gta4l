#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
assert os.geteuid() == 0
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or p.stat().st_uid != 10000: continue
        name = (p/'comm').read_text().strip()
        if not (name.startswith('firefox') or name in ('Web Content','GPU Process','RDD Process')): continue
        print('PROCESS', p.name, name, flush=True)
        for entry in (p/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'GSK_', b'GDK_', b'MOZ_', b'LIBGL_', b'GALLIUM_', b'VK_DRIVER_', b'GTA4L_')):
                print(entry.decode(errors='replace'), flush=True)
        print('GPU_LIBRARIES', sorted({line.split()[-1] for line in (p/'maps').read_text().splitlines()
              if any(item in line for item in ('libgallium','libvulkan_freedreno','libEGL','libLLVM'))}), flush=True)
    except (FileNotFoundError, ProcessLookupError, PermissionError): pass
for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields = dict(line.split(':',1) for line in block.splitlines() if ':' in line)
    if fields.get('P','').startswith('firefox'): print('PACKAGE', fields['P'], fields['V'], flush=True)
PY
dmesg | grep -E 'firefox.*gpu fault|kgsl.*(GPU fault|gpu fault|page fault|context reset|fault detected)' | tail -n 12 || true
