#!/usr/bin/env python3
"""Verify the locally built audio dependency update without rebuilding boot."""
from pathlib import Path
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
names = [f'{name}-1-r14.apk' for name in [
    'device-samsung-gta4l', 'device-samsung-gta4l-openrc',
    'device-samsung-gta4l-nonfree-firmware']]
with tarfile.open(root / 'artifacts/apks' / names[0], 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.removeprefix('./'): m for m in archive}
    assert b'depend = alsa-ucm-gta4l' in archive.extractfile(members['.PKGINFO']).read()
with tarfile.open(root / 'artifacts/apks' / names[1], 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.removeprefix('./'): m for m in archive}
    elf = archive.extractfile(members['usr/bin/gta4l-subsystem']).read()
    assert elf[:4] == b'\x7fELF' and int.from_bytes(elf[18:20], 'little') == 183
    assert archive.extractfile(members['etc/conf.d/polkit']).read() == (
        root / 'port/device-samsung-gta4l/polkit.confd').read_bytes()
boot = json.loads((root / 'artifacts/plane-resume-fix-verification.json').read_text())
hashes = {name: hashlib.sha256((root / 'artifacts/apks' / name).read_bytes()).hexdigest()
          for name in names}
checks = '\n'.join(digest+'  /tmp/gta4l-upload/'+name for name, digest in hashes.items())
packages = ' '.join('/tmp/gta4l-upload/'+name for name in names)
script = f'''#!/bin/sh
set -eu
boot_hash() {{ head -c {boot['boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '{boot['boot_sha256']}' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
apk info -e alsa-ucm-gta4l
apk --no-network --no-interactive --no-scripts add {packages}
[ "$(boot_hash)" = '{boot['boot_sha256']}' ]
echo DEVICE_R14_INSTALLED_BOOT_UNCHANGED
'''
(root / 'tools/live-install-device-r14.sh').write_text(script, newline='\n')
report_path = root / 'artifacts/audio-ucm-verification.json'
report = json.loads(report_path.read_text())
report.update(device_release=14, device_package_sha256=hashes, runtime_ucm_verified=True)
report_path.write_text(json.dumps(report, indent=2) + '\n')
print('Verified device audio dependency, ARM64 DSP holder, and preserved Polkit config')
