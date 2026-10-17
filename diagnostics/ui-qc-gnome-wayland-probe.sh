#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,os,subprocess
assert os.getuid()==10000
binary=Path('/tmp/gta4l-upload/gpu-wayland-render-test')
assert hashlib.sha256(binary.read_bytes()).hexdigest()=='49549f02ed03095daa3bbefa7fdd3e0af499107caf8f037638955c4b3b91d947'
binary.chmod(0o700)
shells=[]
for process in Path('/proc').iterdir():
    try:
        if process.name.isdigit() and process.stat().st_uid==os.getuid() and (process/'comm').read_text().strip()=='gnome-shell':shells.append(process)
    except (FileNotFoundError,ProcessLookupError):pass
assert len(shells)==1
for entry in (shells[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=',b'DBUS_SESSION_BUS_ADDRESS=')):
        key,value=entry.decode().split('=',1);os.environ[key]=value
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1,'Expected one user Wayland socket'
os.environ['WAYLAND_DISPLAY']=sockets[0].name
subprocess.run(['timeout','12','gta4l-zink-run',str(binary),'5'],check=True,timeout=15)
print('GNOME_NATIVE_WAYLAND_ADRENO_PRESENTATION_PASS',flush=True)
PY
