#!/usr/bin/env python3
"""Audit the signed on-demand helpers and generate their guarded live install."""
from pathlib import Path
import hashlib,json,tarfile
workspace=Path(__file__).resolve().parents[1]
records=[];members={}
for name in ('camera-pipewire-gta4l','gps-assistance-gta4l','gps-assistance-gta4l-openrc'):
    path=workspace/'artifacts/apks'/f'{name}-1.0-r0.apk'
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        files={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    assert f'pkgname = {name}\n'.encode() in files['.PKGINFO']
    assert b'pkgver = 1.0-r0\n' in files['.PKGINFO'];members.update(files)
    records.append({'name':name,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for relative,source in (
    ('usr/libexec/gta4l-camera-pipewire-session','port/camera-pipewire-gta4l/gta4l-camera-pipewire-session.py'),
    ('etc/wireplumber/wireplumber.conf.d/60-gta4l-camera.conf','port/camera-pipewire-gta4l/60-gta4l-camera.conf'),
    ('usr/libexec/gta4l-gps-assistance.py','port/gps-assistance-gta4l/gta4l-gps-assistance.py'),
    ('etc/init.d/gta4l-gps-assistance','port/gps-assistance-gta4l/gta4l-gps-assistance.initd')):
    assert members[relative]==(workspace/source).read_bytes(),source
elf=members['usr/libexec/gta4l-camera-pipewire']
assert elf[:4]==b'\x7fELF' and int.from_bytes(elf[18:20],'little')==183
script='''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,signal,subprocess,time
assert os.geteuid()==0
records=json.loads('__RECORDS__')
def versions():
    out={}
    for section in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
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
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\\0') if b'=' in item)
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
'''.replace('__RECORDS__',json.dumps(records))
(workspace/'diagnostics/ui-qc-install-standard-camera-gps.sh').write_text(script,newline='\n')
(workspace/'artifacts/standard-camera-gps-packages-audit.json').write_text(json.dumps({'packages':records,
    'camera_source_elf_sha256':hashlib.sha256(elf).hexdigest(),'runtime_verified':False},indent=2)+'\n')
print('Audited three signed local packages; authored sources match package contents')
