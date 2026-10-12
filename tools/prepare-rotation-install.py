"""Verify local rotation APKs and prepare a boot-preserving live installation."""
from pathlib import Path
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
names = ['firmware-sensors-gta4l-20240703-r0.apk', 'sensors-gta4l-1.0-r0.apk',
         'sensors-gta4l-openrc-1.0-r0.apk', 'rotation-gta4l-1.0-r0.apk']
hashes = {name: hashlib.sha256((root/'artifacts/apks'/name).read_bytes()).hexdigest()
          for name in names}
with tarfile.open(root/'artifacts/apks'/names[0], 'r:gz', ignore_zeros=True) as tar:
    assert not any('registry' in item.name.split('/') for item in tar)
with tarfile.open(root/'artifacts/apks'/names[-1], 'r:gz', ignore_zeros=True) as tar:
    entries = {m.name.removeprefix('./'): m for m in tar}
    matrix = tar.extractfile(entries['etc/udev/rules.d/81-gta4l-sensors.rules']).read()
    assert b'ACCEL_MOUNT_MATRIX}="-1,0,0;0,-1,0;0,0,1"' in matrix
    assert tar.extractfile(entries['usr/bin/gta4l-rotate']).read() == (
        root/'port/rotation-gta4l/gta4l-rotate.py').read_bytes()
checks = '\n'.join(digest+'  /tmp/gta4l-upload/'+name for name, digest in hashes.items())
packages = ' '.join('/tmp/gta4l-upload/'+name for name in names)
script = f'''#!/bin/sh
set -eu
umask 077
boot_hash() {{ head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
apk --no-network --no-interactive --no-scripts add {packages}
udevadm control --reload
udevadm trigger --subsystem-match=fastrpc --sysname-match=adsprpc-smd
udevadm settle --timeout=5
rc-update add gta4l-sensors default
rc-update add iio-sensor-proxy default
rc-service iio-sensor-proxy restart
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo ROTATION_PACKAGES_INSTALLED_BOOT_UNCHANGED
'''
(root/'tools/live-install-rotation.sh').write_text(script, newline='\n')
(root/'artifacts/rotation-verification.json').write_text(json.dumps(dict(
    device='SM-T505', packages=hashes, mount_matrix=[-1,0,0,0,-1,0,0,0,1],
    calibration_partition_writes=False, runtime_rotation_verified=False,
    startup_after_reboot_verified=False), indent=2)+'\n')
print('Verified stock-only firmware and measured rotation rule in local APKs')
