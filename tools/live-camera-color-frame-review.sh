#!/bin/sh
set -eu
printf '%s\n' 'cb6cba438c6021d260f9c25c958f737ec6d189c982d6b17f74694ab25e607d49  /tmp/gta4l-upload/camera-frame-review.py' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import os, pwd, shutil, subprocess
EXPECTED_SIZES={'rear.ppm': (640, 480), 'front.ppm': (640, 480), 'rear-swapped.ppm': (640, 480), 'front-swapped.ppm': (640, 480)}
account=pwd.getpwnam('tablet')
directory=Path(account.pw_dir)/'.cache/gta4l-camera'
directory.mkdir(parents=True,exist_ok=True,mode=0o700)
os.chown(directory,account.pw_uid,account.pw_gid)
os.chmod(directory,0o700)
for name in EXPECTED_SIZES:
    source=Path('/opt/gta4l-camera-dev/r0/data/vendor/camera')/name
    assert source.is_file()
    with source.open('rb') as image:
        assert image.readline()==b'P6\n'
        dimensions=tuple(map(int,image.readline().split()))
        assert image.readline()==b'255\n'
        assert source.stat().st_size==image.tell()+dimensions[0]*dimensions[1]*3
    assert dimensions==EXPECTED_SIZES[name]
    shutil.copyfile(source,directory/name)
    os.chmod(directory/name,0o600)
    os.chown(directory/name,account.pw_uid,account.pw_gid)
shutil.copyfile('/tmp/gta4l-upload/camera-frame-review.py',directory/'review.py')
os.chown(directory/'review.py',account.pw_uid,account.pw_gid)
os.chmod(directory/'review.py',0o600)
session=next(p for p in Path('/proc').iterdir() if p.name.isdigit()
             and p.stat().st_uid==account.pw_uid
             and (p/'comm').read_text().strip()=='xfce4-session')
env=dict(os.environ,HOME=account.pw_dir,USER='tablet',LOGNAME='tablet')
for item in (session/'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DISPLAY=',b'XAUTHORITY=',b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=item.decode().split('=',1); env[key]=value
def become_user():
    os.initgroups(account.pw_name,account.pw_gid)
    os.setgid(account.pw_gid); os.setuid(account.pw_uid)
log=directory/'review.log'
with log.open('wb') as output:
    os.chown(log,account.pw_uid,account.pw_gid); os.chmod(log,0o600)
    process=subprocess.Popen(['/usr/bin/python3',str(directory/'review.py')],
        env=env,stdout=output,stderr=subprocess.STDOUT,start_new_session=True,preexec_fn=become_user)
print('CAMERA_FRAME_REVIEW_STARTED pid='+str(process.pid))
PY
