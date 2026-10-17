#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import hashlib
import subprocess
import time

assert os.getuid()==10000
binary=Path('/tmp/gta4l-upload/gpu-wayland-render-test')
assert hashlib.sha256(binary.read_bytes()).hexdigest()=='49549f02ed03095daa3bbefa7fdd3e0af499107caf8f037638955c4b3b91d947'
binary.chmod(0o700)
sessions=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='kwin_wayland':
            sessions.append(p)
    except (FileNotFoundError,ProcessLookupError):
        pass
assert len(sessions)==1,'Expected one desktop compositor'
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1)
        os.environ[key]=value
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1
os.environ['WAYLAND_DISPLAY']=sockets[0].name
os.environ['LIBGL_KOPPER_DISABLE']='true'
folder=Path.home()/'.cache/gta4l-ui-qc'
folder.mkdir(parents=True,exist_ok=True,mode=0o700)
with (folder/'gpu-wayland.log').open('wb') as log:
    child=subprocess.Popen(['timeout','65','gta4l-zink-run',str(binary),'60'],stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
time.sleep(3)
print((folder/'gpu-wayland.log').read_text()[:7000],flush=True)
print('Launch status:',child.poll(),flush=True)
assert child.poll() is None,'GPU presentation test exited during launch'
print('Native GPU graphics test launched; bounded to 60 seconds',flush=True)
PY
