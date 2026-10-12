#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess,time
account=pwd.getpwnam('tablet')
session=next(p for p in Path('/proc').iterdir() if p.name.isdigit()
    and p.stat().st_uid==account.pw_uid and (p/'comm').read_text().strip()=='xfce4-session')
env=dict(os.environ,HOME=account.pw_dir,USER='tablet',LOGNAME='tablet')
for item in (session/'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DISPLAY=',b'XAUTHORITY=',b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=item.decode().split('=',1); env[key]=value
def become_user():
    os.initgroups(account.pw_name,account.pw_gid)
    os.setgid(account.pw_gid); os.setuid(account.pw_uid)
directory=Path(account.pw_dir)/'.cache/gta4l-camera'
directory.mkdir(parents=True,exist_ok=True,mode=0o700)
os.chown(directory,account.pw_uid,account.pw_gid)
log=directory/'camera-app.log'
with log.open('wb') as output:
    os.chown(log,account.pw_uid,account.pw_gid); os.chmod(log,0o600)
    child=subprocess.Popen(['/usr/bin/gta4l-camera','--camera','rear'],env=env,stdout=output,
        stderr=subprocess.STDOUT,start_new_session=True,preexec_fn=become_user)
time.sleep(2)
print('CAMERA_APP_STARTED pid='+str(child.pid)+' exit='+str(child.poll()))
print(log.read_text())
PY
