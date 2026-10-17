#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,signal,subprocess,time
assert os.geteuid()==0
records=json.loads('[{"name": "camera-pipewire-gta4l", "file": "camera-pipewire-gta4l-1.0-r0.apk", "sha256": "4c5dc4e3ac91d907328ec2c5785c3a09821242f0c50e020e2e88fa56c7daf4a5"}, {"name": "gps-assistance-gta4l", "file": "gps-assistance-gta4l-1.0-r0.apk", "sha256": "49d72798c8ec642df0dda015a39aec8b10221c39f1878bf258c2046bb6fb403f"}, {"name": "gps-assistance-gta4l-openrc", "file": "gps-assistance-gta4l-openrc-1.0-r0.apk", "sha256": "49c7fce8f6f23531a2d74a0d7efe404b8d3aec0356911a8bdfc5806cdcdb9501"}]')
def versions():
    out={}
    for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        v=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in v:out[v['P']]=v['V']
    return out
before=versions();assert before['modemmanager']=='1.25.95_git20261005-r5' and before['gps-gta4l']=='1.0-r5'
assert all(r['name'] not in before for r in records)
with open('/dev/mmcblk0p69','rb') as boot:boot_hash=hashlib.sha256(boot.read(28938256)).hexdigest()
assert boot_hash=='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
paths=[]
for r in records:
    path=Path('/tmp/gta4l-upload')/r['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==r['sha256']
    paths.append(str(path))
args=['apk','--no-network','--no-interactive','--no-scripts','add',*paths]
trial=subprocess.run([args[0],'--simulate',*args[1:]],capture_output=True,text=True,timeout=25)
print(trial.stdout,flush=True);assert trial.returncode==0,trial.stderr
assert not any(s in trial.stdout for s in ('Upgrading','Downgrading','Purging','Removing'))
for line in trial.stdout.splitlines():
    if 'Installing ' in line:assert any('Installing '+r['name']+' (' in line for r in records),line
subprocess.run(args,check=True,timeout=30)
after=versions()
for r in records:assert after.pop(r['name'])=='1.0-r0'
assert after==before
subprocess.run(['rc-update','-q','add','gta4l-gps-assistance','default'],check=True,timeout=5)
subprocess.run(['rc-service','gta4l-gps-assistance','start'],check=True,timeout=15)
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,LOGNAME=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
sockets=[p for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;env['WAYLAND_DISPLAY']=sockets[0].name
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve()==Path('/run/gta4l-camera-pipewire-test/gta4l-camera-pipewire'):
            os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(2)
logs=Path('/run/gta4l-standard-camera-install');logs.mkdir(mode=0o700,exist_ok=True)
stream=open(logs/'session.log','wb');os.chmod(stream.name,0o600)
child=subprocess.Popen(['/usr/libexec/gta4l-camera-pipewire-session'],env=env,user=uid,group=user.pw_gid,
    extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),stdin=subprocess.DEVNULL,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
stream.close();time.sleep(2);assert child.poll() is None
with open('/dev/mmcblk0p69','rb') as boot:assert hashlib.sha256(boot.read(28938256)).hexdigest()==boot_hash
print('STANDARD_CAMERA_AND_GPS_HELPERS_INSTALLED_OTHER_PACKAGES_AND_BOOT_UNCHANGED',flush=True)
print('USER_CAMERA_SUPERVISOR_STARTED',uid,child.pid,flush=True)
PY
