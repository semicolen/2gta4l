"""Prepare a hash-guarded native-app regression launch in the tablet session."""
from pathlib import Path
import hashlib,shutil,tarfile
root=Path(__file__).resolve().parents[1]
with tarfile.open(root/'artifacts/apks/camera-gta4l-1.0-r2.apk',ignore_zeros=True) as package:
    member=next(m for m in package if m.name.removeprefix('./')=='usr/bin/gta4l-camera')
    app_digest=hashlib.sha256(package.extractfile(member).read()).hexdigest()
source=root/'tools/camera-app-photo-regression.py'
shutil.copyfile(source,root/'artifacts/camera-development'/source.name)
digest=hashlib.sha256(source.read_bytes()).hexdigest()
template='''#!/bin/sh
set -eu
printf '%s\\n' '__SHA__  /tmp/gta4l-upload/camera-app-photo-regression.py' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import os,pwd,shutil,subprocess
account=pwd.getpwnam('tablet')
for p in Path('/proc').iterdir():
    if not p.name.isdigit():continue
    try:
        if b'/usr/bin/gta4l-camera' in (p/'cmdline').read_bytes().split(b'\\0'):
            raise SystemExit('Close Camera before the regression test')
    except FileNotFoundError:pass
session=next(p for p in Path('/proc').iterdir() if p.name.isdigit()
    and p.stat().st_uid==account.pw_uid and (p/'comm').read_text().strip()=='xfce4-session')
env=dict(os.environ,HOME=account.pw_dir,USER='tablet',LOGNAME='tablet')
for item in (session/'environ').read_bytes().split(b'\\0'):
    if item.startswith((b'DISPLAY=',b'XAUTHORITY=',b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=item.decode().split('=',1);env[key]=value
directory=Path(account.pw_dir)/'.cache/gta4l-camera'
script=directory/'photo-regression.py'
shutil.copyfile('/tmp/gta4l-upload/camera-app-photo-regression.py',script)
os.chown(script,account.pw_uid,account.pw_gid);os.chmod(script,0o600)
def become_user():
    os.initgroups(account.pw_name,account.pw_gid)
    os.setgid(account.pw_gid);os.setuid(account.pw_uid)
log=directory/'photo-regression-__CAMERA__.log'
with log.open('wb') as output:
    os.chown(log,account.pw_uid,account.pw_gid);os.chmod(log,0o600)
    child=subprocess.run(['/usr/bin/python3',str(script),'--camera','__CAMERA__',
        '--app-sha256','__APP_SHA__'],env=env,stdout=output,stderr=subprocess.STDOUT,
        start_new_session=True,preexec_fn=become_user,timeout=90)
print(log.read_text())
raise SystemExit(child.returncode)
PY
'''
for camera in ('rear','front'):
    (root/f'tools/live-camera-native-{camera}-photo-regression.sh').write_text(
        template.replace('__SHA__',digest).replace('__APP_SHA__',app_digest).replace('__CAMERA__',camera),newline='\n')
print('Prepared exact installed-app photo regression, test SHA256 '+digest)
