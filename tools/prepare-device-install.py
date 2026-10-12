#!/usr/bin/env python3
from pathlib import Path
import argparse
import hashlib
import json
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--release', type=int, required=True)
parser.add_argument('--boot-kind', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
report = json.loads((root / f'artifacts/{args.boot_kind}-verification.json').read_text())
names = [f'{name}-1-r{args.release}.apk' for name in
         ['device-samsung-gta4l', 'device-samsung-gta4l-openrc', 'device-samsung-gta4l-nonfree-firmware']]
paths = [root / 'artifacts/apks' / name for name in names]
with tarfile.open(paths[1], 'r:gz', ignore_zeros=True) as archive:
    members = {member.name.lstrip('./'): member for member in archive}
    helper = archive.extractfile(members['usr/bin/gta4l-subsystem']).read()
    assert helper[:4] == b'\x7fELF' and int.from_bytes(helper[18:20], 'little') == 183
    assert members['etc/init.d/gta4l-adsp'].mode & 0o111
    assert b'/dev/subsys_adsp' in archive.extractfile(members['etc/init.d/gta4l-adsp']).read()
    if args.release >= 11:
        barrier = members['etc/init.d/gta4l-dbus-services']
        assert barrier.mode & 0o111
        body = archive.extractfile(barrier).read()
        assert b'need polkit modemmanager' in body
        assert b'before elogind networkmanager lightdm' in body
hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths]
checks = '\n'.join(f'{digest}  /tmp/gta4l-upload/{path.name}' for path, digest in zip(paths, hashes))
packages = ' '.join('/tmp/gta4l-upload/' + name for name in names)
dbus_registration = 'rc-update -q add gta4l-dbus-services default\n' if args.release >= 11 else ''
script = f'''#!/bin/sh
set -eu
expected={report['boot_sha256']}
boot_hash() {{ head -c {report['boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
apk --no-network --no-interactive --no-scripts add {packages}
rc-update -q add gta4l-ipa default
rc-update -q add gta4l-adsp default
{dbus_registration}\
[ "$(boot_hash)" = "$expected" ]
echo 'Device services installed and registered for next boot; existing boot image verified unchanged.'
'''
(root / f'tools/live-install-device-r{args.release}.sh').write_text(script, newline='\n')
print('Validated ARM64 helper and ADSP service; prepared guarded device package install')
