"""Prepare a hash-checked desktop review of private camera test frames."""
from pathlib import Path
import argparse,hashlib
parser=argparse.ArgumentParser()
parser.add_argument('--full',action='store_true')
parser.add_argument('--color',action='store_true')
options=parser.parse_args()
root=Path(__file__).resolve().parents[1]
script=(root/'tools'/('camera-color-review.py' if options.color else 'camera-frame-review.py')).read_bytes()
out=root/'artifacts/camera-development/camera-frame-review.py'
out.write_bytes(script)
digest=hashlib.sha256(script).hexdigest()
command='''#!/bin/sh
set -eu
printf '%s\\n' '__SHA__  /tmp/gta4l-upload/camera-frame-review.py' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import os, pwd, shutil, subprocess
account=pwd.getpwnam('tablet')
directory=Path(account.pw_dir)/'.cache/gta4l-camera'
directory.mkdir(parents=True,exist_ok=True,mode=0o700)
os.chown(directory,account.pw_uid,account.pw_gid)
os.chmod(directory,0o700)
for name in ('rear.ppm','front.ppm'):
    source=Path('/opt/gta4l-camera-dev/r0/data/vendor/camera')/name
    assert source.is_file()
    with source.open('rb') as image:
        assert image.readline()==b'P6\\n'
        dimensions=tuple(map(int,image.readline().split()))
        assert image.readline()==b'255\\n'
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
for item in (session/'environ').read_bytes().split(b'\\0'):
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
'''.replace('__SHA__',digest)
sizes={'rear.ppm':(3264,2448),'front.ppm':(2592,1944)} if options.full else {'rear.ppm':(640,480),'front.ppm':(640,480)}
if options.color:
    sizes.update({'rear-swapped.ppm':(640,480),'front-swapped.ppm':(640,480)})
    command=command.replace("for name in ('rear.ppm','front.ppm'):","for name in EXPECTED_SIZES:")
command=command.replace("account=pwd.getpwnam('tablet')", "EXPECTED_SIZES="+repr(sizes)+"\naccount=pwd.getpwnam('tablet')")
name='live-camera-color-frame-review.sh' if options.color else ('live-camera-full-frame-review.sh' if options.full else 'live-camera-frame-review.sh')
(root/'tools'/name).write_text(command,newline='\n')
print('Prepared private frame review, SHA256 '+digest)
