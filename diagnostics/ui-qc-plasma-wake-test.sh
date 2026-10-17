#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import time
assert os.getuid()==10000
sessions=[p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid()
          and (p/'comm').read_text().strip()=='kwin_wayland']
assert len(sessions)==1
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1)
        os.environ[key]=value
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1
os.environ['WAYLAND_DISPLAY']=sockets[0].name
os.environ['QT_QPA_PLATFORM']='wayland'
try:
    subprocess.run(['kscreen-doctor','--dpms','off'],check=True,timeout=10)
    time.sleep(3)
finally:
    subprocess.run(['kscreen-doctor','--dpms','on'],check=True,timeout=10)
time.sleep(2)
subprocess.run(['kscreen-doctor','--dpms','show'],check=True,timeout=10)
subprocess.run(['kscreen-doctor','-o'],check=True,timeout=10)
print('WAYLAND_DISPLAY_OFF_ON_CYCLE_COMPLETE',flush=True)
PY
