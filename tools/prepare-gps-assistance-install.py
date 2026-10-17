#!/usr/bin/env python3
"""Audit the locally built assistance update and prepare an offline install."""
from pathlib import Path
import argparse,hashlib,json,tarfile
parser=argparse.ArgumentParser();parser.add_argument('--revision',type=int,choices=(4,5),default=4)
revision=parser.parse_args().revision
workspace=Path(__file__).resolve().parents[1]
names=['modemmanager','modemmanager-lang','modemmanager-openrc','modemmanager-udev','libmm-glib','gps-gta4l']
records=[]
for name in names:
    base='1.0' if name=='gps-gta4l' else '1.25.95_git20261005'
    version=f'{base}-r{revision}'
    path=workspace/'artifacts/apks'/f'{name}-{version}.apk'
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        members={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    assert f'pkgname = {name}\n'.encode() in members['.PKGINFO']
    assert f'pkgver = {version}\n'.encode() in members['.PKGINFO']
    if name=='modemmanager':
        elf=members['usr/sbin/ModemManager']
        assert elf[:4]==b'\x7fELF' and int.from_bytes(elf[18:20],'little')==183
        assert b'Preparing SM-T505 GPS engine through QMI LOC' in elf
    records.append({'name':name,'version':version,'previous_version':f'{base}-r{revision-1}',
        'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
script='''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess,tempfile
assert os.geteuid()==0
records=json.loads('__RECORDS__')
def versions():
    out={}
    for block in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
        v=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if 'P' in v:out[v['P']]=v['V']
    return out
def boot():
    with open('/dev/mmcblk0p69','rb') as f:return hashlib.sha256(f.read(28938256)).hexdigest()
expected='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
assert boot()==expected
before=versions(); paths=[]
for record in records:
    old=record['previous_version']
    assert before[record['name']]==old
    path=Path('/tmp/gta4l-upload')/record['file']
    assert path.is_file() and not path.is_symlink()
    assert hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256']
    paths.append(str(path))
args=['apk','--no-network','--no-interactive','--no-scripts','add',*paths]
trial=subprocess.run([args[0],'--simulate',*args[1:]],capture_output=True,text=True,timeout=30)
print(trial.stdout,flush=True);assert trial.returncode==0,trial.stderr
assert not any(word in trial.stdout for word in ('Purging','Removing','Downgrading'))
for line in trial.stdout.splitlines():
    if 'Upgrading' in line:assert any(r['name']+' (' in line for r in records),line
subprocess.run(args,check=True,timeout=45)
after=versions()
for record in records:
    assert after.pop(record['name'])==record['version'];before.pop(record['name'])
assert before==after
# Prevent a desktop client from racing OpenRC's supervised restart.
service=Path('/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service')
original=service.read_bytes()
with tempfile.TemporaryDirectory(prefix='gta4l-mm-restart-') as directory:
    override=Path(directory)/'disabled.service'
    override.write_text('[D-BUS Service]\\nName=org.freedesktop.ModemManager1\\nExec=/bin/false\\nUser=root\\n')
    subprocess.run(['mount','--bind',str(override),str(service)],check=True)
    reload=['dbus-send','--system','--type=method_call','--print-reply','--dest=org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus.ReloadConfig']
    try:
        subprocess.run(reload,check=True,timeout=10)
        subprocess.run(['rc-service','modemmanager','stop'],check=True,timeout=20)
        subprocess.run(['rc-service','modemmanager','start'],check=True,timeout=20)
    finally:
        subprocess.run(['umount',str(service)],check=True)
        subprocess.run(reload,check=True,timeout=10)
assert service.read_bytes()==original
assert boot()==expected
os.sync()
print('GPS_ASSISTANCE_R__REVISION___INSTALLED_OTHER_PACKAGES_AND_BOOT_UNCHANGED',flush=True)
PY
'''.replace('__RECORDS__',json.dumps(records)).replace('__REVISION__',str(revision))
(workspace/'diagnostics/ui-qc-install-gps-assistance.sh').write_text(script,newline='\n')
(workspace/f'artifacts/gps-assistance-r{revision}-audit.json').write_text(json.dumps({'packages':records,'runtime_verified':False},indent=2)+'\n')
print('Audited six matching ARM64 update packages; generated guarded install')
