#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import time
assert os.getuid()==10000
sessions=[p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid()
          and (p/'comm').read_text().strip() in ('kwin_wayland','gnome-shell')]
assert len(sessions)==1, 'Expected one native Wayland desktop session'
graphics_prefixes=(b'LIBGL_',b'GALLIUM_',b'MESA_',b'VK_',b'GTA4L_ZINK_',b'QT_QUICK_BACKEND=',b'LD_LIBRARY_PATH=')
for key in list(os.environ):
    if key.startswith(('LIBGL_','GALLIUM_','MESA_','VK_','GTA4L_ZINK_')) or key in ('QT_QUICK_BACKEND','LD_LIBRARY_PATH'):
        del os.environ[key]
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=',b'DISPLAY=')+graphics_prefixes):
        key,value=entry.decode().split('=',1)
        os.environ[key]=value
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1
os.environ['WAYLAND_DISPLAY']=sockets[0].name
os.environ['GDK_BACKEND']='wayland'
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and b'/usr/bin/gta4l-camera' in (p/'cmdline').read_bytes().split(b'\0'):
            raise RuntimeError('Camera is already open; close it before launching another test')
    except (FileNotFoundError,ProcessLookupError):
        pass
folder=Path.home()/'.cache/gta4l-ui-qc'
folder.mkdir(parents=True,exist_ok=True,mode=0o700)
with (folder/'camera.log').open('wb') as log:
    child=subprocess.Popen(['/usr/bin/gta4l-camera','--camera','rear'],
                           stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
time.sleep(2)
assert child.poll() is None, 'Camera app exited during launch; read its private log'
print('Camera opened in native desktop session; PID',child.pid,flush=True)
PY
