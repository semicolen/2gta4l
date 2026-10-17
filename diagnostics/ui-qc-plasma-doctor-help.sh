#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
assert os.getuid()==10000
p = next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid()
         and (p/'comm').read_text().strip()=='kwin_wayland')
for entry in (p/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1)
        os.environ[key]=value
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1
os.environ['WAYLAND_DISPLAY']=sockets[0].name
os.environ['QT_QPA_PLATFORM']='wayland'
subprocess.run(['kscreen-doctor','--help'],timeout=10,check=True)
subprocess.run(['kwriteconfig6','--help'],timeout=10,check=True)
PY
