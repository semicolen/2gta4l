#!/usr/bin/env python3
"""Read factory registry into a private cache; never mount/write persist."""
import os
from pathlib import Path
import subprocess

os.umask(0o077)
BASE = Path('/var/lib/gta4l-sensors')
RUNTIME = BASE / 'runtime'
STATIC = Path('/usr/share/gta4l-sensors')
PARTITION = Path('/dev/disk/by-partlabel/persist')
if os.geteuid() != 0:
    raise SystemExit('Sensor registry preparation requires root')
BASE.mkdir(mode=0o700, parents=True, exist_ok=True)
BASE.chmod(0o700)
RUNTIME.mkdir(mode=0o700, exist_ok=True)
(RUNTIME / 'sensors/config').mkdir(mode=0o700, parents=True, exist_ok=True)
registry = RUNTIME / 'sensors/registry'
if not registry.is_dir():
    # Resolve the named partition and verify its kernel partition identity.
    device = PARTITION.resolve(strict=True)
    event = Path('/sys/class/block') / device.name / 'uevent'
    if 'PARTNAME=persist' not in event.read_text().splitlines():
        raise SystemExit('The persist partition identity did not match')
    result = subprocess.run(['debugfs', '-R',
        f'rdump /sensors/registry/registry "{RUNTIME / "sensors"}"', str(device)],
        capture_output=True, text=True, timeout=30)
    if result.returncode or not registry.is_dir():
        raise SystemExit('Could not read the factory sensor registry')
files = list(registry.iterdir())
if len(files) < 100 or not any(p.name.startswith('bmi26x') for p in files):
    raise SystemExit('Factory Bosch sensor registry is incomplete')
for path in registry.rglob('*'):
    if path.is_symlink() or not (path.is_file() or path.is_dir()):
        raise SystemExit('Unexpected registry file type')
    path.chmod(0o700 if path.is_dir() else 0o600)
registry.chmod(0o700)
# Empty config makes the DSP use its pre-parsed factory registry. The file
# server is read-only, and the original calibration partition is untouched.
for relative, target in [('dsp', STATIC / 'dsp'),
                         ('sensors/sns_reg.conf', STATIC / 'sns_reg.conf'),
                         ('socinfo', Path('/sys/devices/soc0'))]:
    link = RUNTIME / relative
    if link.is_symlink():
        if link.resolve() != target.resolve():
            raise SystemExit(f'Unexpected sensor link: {relative}')
    elif link.exists():
        raise SystemExit(f'Unexpected sensor path: {relative}')
    else:
        link.symlink_to(target, target_is_directory=target.is_dir())
print(f'Sensor registry ready: {len(files)} cached factory files')
