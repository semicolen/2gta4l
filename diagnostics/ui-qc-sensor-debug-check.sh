#!/bin/sh
set -eu
umask 077
python3 - <<'PY'
from pathlib import Path
import os,subprocess
assert os.geteuid()==0
folder=Path('/var/log/gta4l/sensor-proxy-private')
folder.mkdir(mode=0o700,exist_ok=True)
conf=Path('/etc/conf.d/iio-sensor-proxy')
original=conf.read_bytes()
assert b'command_args=' not in original
try:
    conf.write_bytes(original+b'\n# Temporary diagnostic; original restored by caller.\n'
        b'export G_MESSAGES_DEBUG=all\n'
        b'output_log="/var/log/gta4l/sensor-proxy-private/debug.log"\n'
        b'error_log="$output_log"\n')
    subprocess.run(['rc-service','iio-sensor-proxy','restart'],check=True,timeout=15)
    result=subprocess.run(['timeout','12','monitor-sensor','--accel'],check=False,timeout=16)
    assert result.returncode in (0,124,143,-15),result.returncode
finally:
    conf.write_bytes(original)
    os.sync()
print('ORIGINAL_SENSOR_PROXY_CONFIG_RESTORED; diagnostic logging ends at next service start',flush=True)
path=folder/'debug.log'
with path.open('rb') as source:
    source.seek(max(0,path.stat().st_size-16000));print(source.read().decode(errors='replace'),flush=True)
PY
