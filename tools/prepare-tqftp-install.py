#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
report = json.loads((root / 'artifacts/plane-resume-fix-verification.json').read_text())
names = ['tqftpserv-gta4l-1.2-r0.apk'] + [f'{name}-1-r12.apk' for name in
    ['device-samsung-gta4l', 'device-samsung-gta4l-openrc', 'device-samsung-gta4l-nonfree-firmware']]
for name in names[:2]:
    with tarfile.open(root / 'artifacts/apks' / name, 'r:gz', ignore_zeros=True) as archive:
        members = {m.name.lstrip('./'): m for m in archive}
        if name.startswith('tqftp'):
            binary = archive.extractfile(members['usr/bin/tqftpserv-gta4l']).read()
            assert binary[:4] == b'\x7fELF' and int.from_bytes(binary[18:20], 'little') == 183
            service = archive.extractfile(members['etc/init.d/gta4l-tqftpserv']).read()
            assert b'export TQFTPSERV_FW_DIR=/lib/firmware/postmarketos' in service
with tarfile.open(root / 'artifacts/apks' / names[2], 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.lstrip('./'): m for m in archive}
    for service in ['gta4l-modem', 'gta4l-adsp']:
        assert b'gta4l-tqftpserv' in archive.extractfile(members['etc/init.d/' + service]).read()
checks = '\n'.join(hashlib.sha256((root / 'artifacts/apks' / name).read_bytes()).hexdigest()
                   + '  /tmp/gta4l-upload/' + name for name in names)
packages = ' '.join('/tmp/gta4l-upload/' + name for name in names)
script = f'''#!/bin/sh
set -eu
expected={report['boot_sha256']}
boot_hash() {{ head -c {report['boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
# OpenRC also stops the two firmware consumers before removing their provider.
rc-service tqftpserv stop
apk --no-network --no-interactive --no-scripts add {packages}
rc-update -q del tqftpserv default 2>/dev/null || true
rc-update -q add gta4l-tqftpserv default
rc-update -q add gta4l-dbus-services default
/usr/libexec/rc/bin/rc-depend -u
rc-service gta4l-tqftpserv start
rc-service gta4l-adsp start
rc-service gta4l-modem start
rc-service gta4l-ipa start
[ "$(boot_hash)" = "$expected" ]
echo 'Installed local downstream firmware server; existing boot image verified unchanged.'
'''
(root / 'tools/live-install-tqftp-downstream.sh').write_text(script, newline='\n')
print('Validated ARM64 firmware server and dependencies; prepared guarded offline install')
