#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,subprocess,signal
assert os.getuid()==10000
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='gnome-shell')
environment=dict(entry.decode().split('=',1) for entry in (shell/'environ').read_bytes().split(b'\0') if b'=' in entry)
os.environ.clear();os.environ.update(environment)
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;os.environ['WAYLAND_DISPLAY']=sockets[0].name
print('CURRENT_DESKTOP',os.environ.get('XDG_CURRENT_DESKTOP'),flush=True)
for command in (['/usr/bin/gnome-control-center'],['/usr/bin/gnome-calculator']):
    print('=== Direct launch',command[0],'native session environment ===',flush=True)
    child=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
    try:
        output,_=child.communicate(timeout=10)
        print('EXIT',child.returncode,flush=True)
    except subprocess.TimeoutExpired:
        print('ALIVE_AFTER_10_SECONDS',child.pid,flush=True)
        os.killpg(child.pid,signal.SIGTERM)
        try:output,_=child.communicate(timeout=4)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid,signal.SIGKILL);output,_=child.communicate(timeout=3)
    print(output[-10000:],flush=True)
print('DIRECT_APP_PROBE_COMPLETE',flush=True)
PY
