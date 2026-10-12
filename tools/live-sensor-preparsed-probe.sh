#!/bin/sh
set -eu
umask 077
python3 - <<'PY'
from pathlib import Path
import shutil
source = Path('/var/lib/gta4l-sensors/probe-20261011')
target = Path('/var/lib/gta4l-sensors/preparsed-20261011')
(target/'sensors/config').mkdir(parents=True, exist_ok=True)
for name in ['dsp', 'socinfo', 'sensors/registry', 'sensors/sns_reg.conf']:
    path = target/name
    if not path.exists():
        path.symlink_to(source/name, target_is_directory=(source/name).is_dir())
PY
cp /var/log/gta4l/sensors-rpc-probe.log /var/log/gta4l/sensors-rpc-full-config.log
nohup timeout 120 /usr/bin/hexagonrpcd-gta4l -s -f /dev/adsprpc-smd-secure -R /var/lib/gta4l-sensors/preparsed-20261011 >/var/log/gta4l/sensors-rpc-preparsed.log 2>&1 </dev/null &
echo "RPC pre-parsed probe PID $!"
sleep 5
timeout 25 ssccli --sensor=accelerometer --timeout=5 --debug || true
tail -n 80 /var/log/gta4l/sensors-rpc-preparsed.log
echo SENSOR_PREPARSED_PROBE_END
