#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,signal,subprocess,time
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,XDG_RUNTIME_DIR=f'/run/user/{uid}',WIREPLUMBER_DEBUG='D')
def processes():
    out=[]
    for p in Path('/proc').iterdir():
        try:
            if p.name.isdigit() and p.stat().st_uid==uid and (p/'comm').read_text().strip()=='wireplumber':out.append(int(p.name))
        except (OSError,ProcessLookupError):pass
    return out
for pid in processes():os.kill(pid,signal.SIGTERM)
for attempt in range(20):
    if not processes():break
    time.sleep(.1)
assert not processes(),'WirePlumber has not stopped'
run=Path('/run/gta4l-camera-pipewire-test')
log=open(run/'wireplumber.log','wb');os.chmod(log.name,0o600)
child=subprocess.Popen(['/usr/bin/wireplumber'],env=env,user=uid,group=user.pw_gid,
    extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),stdin=subprocess.DEVNULL,
    stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
log.close();time.sleep(2)
assert child.poll() is None
print('TEMPORARY_WIREPLUMBER_DEBUG_STARTED',child.pid,flush=True)
path=Path('/usr/share/wireplumber/scripts/lib/linking-utils.lua')
if path.exists():
    text=path.read_text();start=text.find('function canLink')
    if start>=0:print('CAN_LINK',text[start:text.find('\nend',start)+4],flush=True)
PY
