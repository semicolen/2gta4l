from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
names = ['hexagonrpc-gta4l-0.5.0-r0.apk', 'xinput-1.6.4-r2.apk',
         'iio-sensor-proxy-3.9-r3.apk', 'iio-sensor-proxy-openrc-3.9-r3.apk',
         'iio-sensor-proxy-udev-3.9-r3.apk']
files = [root/'artifacts/apks'/n for n in names]
files.append(root/'artifacts/gta4l-sensor-files-private.tar.gz')
assert all(p.is_file() for p in files)
lines = '\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name for p in files)
script = '''#!/bin/sh
set -eu
umask 077
cd /tmp/gta4l-upload
sha256sum -c - <<'GTA4L_HASHES'
''' + lines + '''
GTA4L_HASHES
apk --no-network --no-interactive --no-scripts add ''' + ' '.join('./'+n for n in names) + '''
python3 - <<'PY'
from pathlib import Path, PurePosixPath
import tarfile
import os
target = Path('/var/lib/gta4l-sensors/probe-20261011')
target.mkdir(parents=True, exist_ok=True, mode=0o700)
with tarfile.open('/tmp/gta4l-upload/gta4l-sensor-files-private.tar.gz') as tar:
    for member in tar.getmembers():
        parts = PurePosixPath(member.name).parts
        assert not member.name.startswith('/') and '..' not in parts
        assert member.isdir() or member.isfile(), member.name
    tar.extractall(target, filter='data')
for path in target.rglob('*'):
    path.chmod(0o700 if path.is_dir() else 0o600)
socinfo = target/'socinfo'
if not socinfo.exists():
    socinfo.symlink_to('/sys/devices/soc0', target_is_directory=True)
assert (target/'sensors/registry/sns_reg_config').is_file()
PY
mkdir -p /var/log/gta4l
nohup timeout 120 /usr/bin/hexagonrpcd-gta4l -s -f /dev/adsprpc-smd-secure -R /var/lib/gta4l-sensors/probe-20261011 >/var/log/gta4l/sensors-rpc-probe.log 2>&1 </dev/null &
echo "RPC probe PID $!"
sleep 6
timeout 25 ssccli --sensor=accelerometer --timeout=5 --debug || true
tail -n 100 /var/log/gta4l/sensors-rpc-probe.log
echo SENSOR_RPC_PROBE_END
'''
(root/'tools/live-sensor-rpc-probe.sh').write_text(script, newline='\n')
print('Prepared hash-guarded sensor RPC diagnostic')
