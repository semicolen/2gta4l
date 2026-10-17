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
os.environ['GSK_RENDERER']='gl'
for command in (['/usr/bin/gnome-control-center'],['/usr/bin/gnome-calculator']):
    print('=== GSK_RENDERER=gl',command[0],'===',flush=True)
    child=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
    try:
        output,_=child.communicate(timeout=10)
        print('EXIT',child.returncode,flush=True)
    except subprocess.TimeoutExpired:
        print('ALIVE_AFTER_10_SECONDS',child.pid,flush=True)
        libs=sorted({line.split()[-1] for line in Path('/proc',str(child.pid),'maps').read_text().splitlines() if any(s in line for s in ('libgallium','libvulkan_freedreno','libLLVM'))})
        print('MAPPED_GRAPHICS_LIBRARIES',libs,flush=True)
        os.killpg(child.pid,signal.SIGTERM)
        try:output,_=child.communicate(timeout=4)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid,signal.SIGKILL);output,_=child.communicate(timeout=3)
    print(output[-9000:],flush=True)
print('GTK_OPENGL_COMPARISON_COMPLETE',flush=True)
PY
