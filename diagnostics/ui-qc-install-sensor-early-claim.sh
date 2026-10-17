#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess
assert os.geteuid()==0
packages=json.loads('[{"name": "iio-sensor-proxy", "file": "iio-sensor-proxy-3.9-r4.apk", "sha256": "74bf2338b0a3a90a1ccb7b464190e37affe55913b8d6c8ed341ee35fa66e9c51"}, {"name": "iio-sensor-proxy-openrc", "file": "iio-sensor-proxy-openrc-3.9-r4.apk", "sha256": "f76449d0debfc436b82e42eccdddbda8df8e707720bd80d7e5abbb17a3f246eb"}, {"name": "iio-sensor-proxy-udev", "file": "iio-sensor-proxy-udev-3.9-r4.apk", "sha256": "5ce5c80c908feaa668b0e39df754532b68f6c86988c52755c7b8d2b2dded6ff1"}]')
def versions():
    result={}
    for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
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
assert Path('/etc/conf.d/iio-sensor-proxy').read_text().strip()=='# Start the downstream DSP reverse-RPC listener before SensorProxy discovery.\nrc_need="gta4l-sensors"'
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
