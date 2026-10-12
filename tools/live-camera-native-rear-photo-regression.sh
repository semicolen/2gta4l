#!/bin/sh
set -eu
printf '%s\n' '54863a49a68c0d530daaf998ba13b82065022c6bc412d23e4ed5558b480ffb89  /tmp/gta4l-upload/camera-app-photo-regression.py' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import os,pwd,shutil,subprocess
account=pwd.getpwnam('tablet')
for p in Path('/proc').iterdir():
    if not p.name.isdigit():continue
    try:
        if b'/usr/bin/gta4l-camera' in (p/'cmdline').read_bytes().split(b'\0'):
            raise SystemExit('Close Camera before the regression test')
    except FileNotFoundError:pass
session=next(p for p in Path('/proc').iterdir() if p.name.isdigit()
    and p.stat().st_uid==account.pw_uid and (p/'comm').read_text().strip()=='xfce4-session')
env=dict(os.environ,HOME=account.pw_dir,USER='tablet',LOGNAME='tablet')
for item in (session/'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DISPLAY=',b'XAUTHORITY=',b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=item.decode().split('=',1);env[key]=value
directory=Path(account.pw_dir)/'.cache/gta4l-camera'
script=directory/'photo-regression.py'
shutil.copyfile('/tmp/gta4l-upload/camera-app-photo-regression.py',script)
os.chown(script,account.pw_uid,account.pw_gid);os.chmod(script,0o600)
def become_user():
    os.initgroups(account.pw_name,account.pw_gid)
    os.setgid(account.pw_gid);os.setuid(account.pw_uid)
log=directory/'photo-regression-rear.log'
with log.open('wb') as output:
    os.chown(log,account.pw_uid,account.pw_gid);os.chmod(log,0o600)
    child=subprocess.run(['/usr/bin/python3',str(script),'--camera','rear',
        '--app-sha256','b2ef9c23426b9bb6388ec3fafea39308cedf0d884b80289e73bfa301019d7fbb'],env=env,stdout=output,stderr=subprocess.STDOUT,
        start_new_session=True,preexec_fn=become_user,timeout=90)
print(log.read_text())
raise SystemExit(child.returncode)
PY
