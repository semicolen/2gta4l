#!/bin/sh
set -eu
umask 077
cd /tmp/gta4l-upload
sha256sum -c - <<'GTA4L_HASHES'
27066d691a7864a034bd992ba235f0347a2c2f4ad507243aedf9a068789182d9  hexagonrpc-gta4l-0.5.0-r0.apk
45aa53f91312be855b563e56ce9b89b2493b47dc56bd6ceff3b8ec2c4b7323f9  xinput-1.6.4-r2.apk
3d60cd85ea718fb409e87d9218ed1135a64e42cc5ee7363f782b7d2460d9737f  iio-sensor-proxy-3.9-r3.apk
d378a32def33e4b47679ccf93e8da12a13837393475098de1cc244213edcc914  iio-sensor-proxy-openrc-3.9-r3.apk
2e79895e9bde7a90fe055082c38affc3e097adee3accd0a792831f22066d502a  iio-sensor-proxy-udev-3.9-r3.apk
3374fb467c37f222574604bf8dd816e9c70ddd50be462851a5d1787a80945870  gta4l-sensor-files-private.tar.gz
GTA4L_HASHES
apk --no-network --no-interactive --no-scripts add ./hexagonrpc-gta4l-0.5.0-r0.apk ./xinput-1.6.4-r2.apk ./iio-sensor-proxy-3.9-r3.apk ./iio-sensor-proxy-openrc-3.9-r3.apk ./iio-sensor-proxy-udev-3.9-r3.apk
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
