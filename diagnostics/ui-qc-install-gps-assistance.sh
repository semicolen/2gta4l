#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess,tempfile
assert os.geteuid()==0
records=json.loads('[{"name": "modemmanager", "version": "1.25.95_git20261005-r5", "previous_version": "1.25.95_git20261005-r4", "file": "modemmanager-1.25.95_git20261005-r5.apk", "sha256": "0fc722655fc0dd52fa01075a6196eec9bb484534f97bc0b206b820ed4203c510"}, {"name": "modemmanager-lang", "version": "1.25.95_git20261005-r5", "previous_version": "1.25.95_git20261005-r4", "file": "modemmanager-lang-1.25.95_git20261005-r5.apk", "sha256": "fb46ab93f2a2f0eef18088562d476d312b888d7d4f357e8d7029725584e0f4b2"}, {"name": "modemmanager-openrc", "version": "1.25.95_git20261005-r5", "previous_version": "1.25.95_git20261005-r4", "file": "modemmanager-openrc-1.25.95_git20261005-r5.apk", "sha256": "69f912dcf4873805248c269d868ea0fdc79032e2225c19a6eec36fbaa8adfa99"}, {"name": "modemmanager-udev", "version": "1.25.95_git20261005-r5", "previous_version": "1.25.95_git20261005-r4", "file": "modemmanager-udev-1.25.95_git20261005-r5.apk", "sha256": "e1fea47cc52ad624c858ca41caebb0ebc5cf422aa9f09a283148f3bc9b1838d7"}, {"name": "libmm-glib", "version": "1.25.95_git20261005-r5", "previous_version": "1.25.95_git20261005-r4", "file": "libmm-glib-1.25.95_git20261005-r5.apk", "sha256": "3cdc5805cd5e5780cae26f94500b323ea056054552530ad6db12c9b498233e6e"}, {"name": "gps-gta4l", "version": "1.0-r5", "previous_version": "1.0-r4", "file": "gps-gta4l-1.0-r5.apk", "sha256": "b7a554aaff78b67d87983843f25b5c7d1b208341b92e7ea203fdf8446fb2e0bb"}]')
def versions():
    out={}
    for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
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
    override.write_text('[D-BUS Service]\nName=org.freedesktop.ModemManager1\nExec=/bin/false\nUser=root\n')
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
print('GPS_ASSISTANCE_R5_INSTALLED_OTHER_PACKAGES_AND_BOOT_UNCHANGED',flush=True)
PY
