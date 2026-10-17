#!/usr/bin/env python3
"""Audit rebuilt service/rules and generate a version-guarded offline install."""
from pathlib import Path
import hashlib,json,tarfile
workspace=Path(__file__).resolve().parents[1]
def files(path):
    result={}
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        for member in archive:
            name=member.name.lstrip('./')
            if member.isfile() and name and not member.name.lstrip('./').startswith(('PKGINFO','SIGN.')):
                result[name]=hashlib.sha256(archive.extractfile(member).read()).hexdigest()
    return result
packages=[]
for suffix in ('','-openrc','-udev'):
    name='iio-sensor-proxy'+suffix
    path=workspace/'artifacts/apks'/(name+'-3.9-r4.apk')
    if suffix:assert files(path)==files(workspace/'artifacts/apks'/(name+'-3.9-r3.apk'))
    packages.append({'name':name,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
payload=json.dumps(packages)
script='''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess
assert os.geteuid()==0
packages=json.loads('__PACKAGES__')
def versions():
    result={}
    for block in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
        fields=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if 'P' in fields:result[fields['P']]=fields['V']
    return result
before=versions()
for record in packages:
    assert before[record['name']]=='3.9-r3'
    path=Path('/tmp/gta4l-upload')/record['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256']
args=['apk','--no-network','--no-interactive','--no-scripts','add']+[str(Path('/tmp/gta4l-upload')/r['file']) for r in packages]
trial=subprocess.run(args[:1]+['--simulate']+args[1:],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(trial.stdout,flush=True)
assert trial.returncode==0
assert not any(word in trial.stdout for word in ('Purging','Removing','Downgrading'))
for line in trial.stdout.splitlines():
    if 'Upgrading' in line:assert any(r['name']+' (' in line for r in packages),line
subprocess.run(['rc-service','iio-sensor-proxy','stop'],check=True,timeout=15)
subprocess.run(args,check=True,timeout=45)
after=versions()
for record in packages:
    assert after.pop(record['name'])=='3.9-r4'
    before.pop(record['name'])
assert before==after
assert Path('/etc/conf.d/iio-sensor-proxy').read_text().strip()=='# Start the downstream DSP reverse-RPC listener before SensorProxy discovery.\\nrc_need="gta4l-sensors"'
# Start the observer first so its claim can arrive during initial discovery.
observer=subprocess.Popen(['monitor-sensor','--accel'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
    subprocess.run(['rc-service','iio-sensor-proxy','start'],check=True,timeout=15)
    try:output,_=observer.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        observer.terminate();output,_=observer.communicate(timeout=5)
    print('=== Immediate sensor observer ===',flush=True)
    print(output,flush=True)
finally:
    if observer.poll() is None:observer.kill();observer.wait(timeout=5)
os.sync()
print('SENSOR_PROXY_R4_INSTALLED; existing service/rules and other packages preserved',flush=True)
PY
'''.replace('__PACKAGES__',payload)
(workspace/'diagnostics/ui-qc-install-sensor-early-claim.sh').write_text(script,newline='\n')
(workspace/'artifacts/sensor-early-claim-package-audit.json').write_text(json.dumps({'packages':packages,'openrc_and_udev_file_contents_unchanged':True,'runtime_verified':False},indent=2)+'\n')
print(json.dumps(packages,indent=2))
