#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
assert os.getuid()==10000
sessions=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='kwin_wayland':sessions.append(p)
    except (FileNotFoundError,ProcessLookupError):pass
assert len(sessions)==1
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1);os.environ[key]=value
print('=== Active compositor graphics ===',flush=True)
r=subprocess.run(['timeout','10','qdbus6','org.kde.KWin','/KWin','supportInformation'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(r.stdout[-16000:],flush=True)
print('query exit',r.returncode,flush=True)
print('=== Saved display session definitions ===',flush=True)
for p in Path('/usr/share/wayland-sessions').glob('*.desktop'):
    print(p.name,flush=True)
    print('\n'.join(line for line in p.read_text().splitlines() if line.startswith(('Exec=','TryExec=','DesktopNames=','Name='))),flush=True)
for p in (Path('/etc/sddm.conf'),Path('/var/lib/sddm/state.conf')):
    if p.exists():
        try: print(p, '\n'.join(x for x in p.read_text().splitlines() if x.startswith(('Session=','User='))),flush=True)
        except PermissionError: print(p, 'requires root; session graphics query succeeded',flush=True)
print('GPU_COMPOSITOR_STATE_COMPLETE',flush=True)
PY
