#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import re
for directory in ('/etc/profile.d','/etc/environment.d','/home/tablet/.config/plasma-workspace/env','/etc/xdg/plasma-workspace/env'):
    print('=== '+directory+' ===',flush=True)
    for p in Path(directory).glob('*'):
        if p.is_file():
            text=p.read_text(errors='replace')
            if any(x in text for x in ('LIBGL_ALWAYS_SOFTWARE','GALLIUM_DRIVER','QT_QUICK_BACKEND','LD_LIBRARY_PATH','gta4l')):
                print(p,flush=True)
                print('\n'.join(x for x in text.splitlines() if any(y in x for y in ('LIBGL_','GALLIUM_','QT_QUICK_BACKEND','LD_LIBRARY_PATH','gta4l'))),flush=True)
for p in (Path('/etc/environment'),Path('/usr/lib/libexec/plasma-dbus-run-session-if-needed')):
    if p.exists():print(p,p.read_text()[:8000],flush=True)
print('GPU_SESSION_LAYOUT_COMPLETE',flush=True)
PY
