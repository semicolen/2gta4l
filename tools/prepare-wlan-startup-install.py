#!/usr/bin/env python3
"""Verify the local ARM64 packages and prepare a boot-preserving update."""
from pathlib import Path
import hashlib
import json
import re
import tarfile

root = Path(__file__).resolve().parents[1]
report = json.loads((root / 'artifacts/plane-resume-fix-verification.json').read_text())
names = ['wlfw-gta4l-1.0-r0.apk'] + [f'{name}-1-r13.apk' for name in
    ['device-samsung-gta4l', 'device-samsung-gta4l-openrc', 'device-samsung-gta4l-nonfree-firmware']]
with tarfile.open(root / 'artifacts/apks' / names[0], 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.lstrip('./'): m for m in archive}
    elf = archive.extractfile(members['usr/bin/wlfw-initialize-gta4l']).read()
    assert elf[:4] == b'\x7fELF' and int.from_bytes(elf[18:20], 'little') == 183
    assert members['etc/init.d/gta4l-wlan'].mode & 0o111
    service = archive.extractfile(members['etc/init.d/gta4l-wlan']).read()
    assert b'before networkmanager wpa_supplicant' in service
with tarfile.open(root / 'artifacts/apks' / names[2], 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.lstrip('./'): m for m in archive}
    config = archive.extractfile(members['etc/conf.d/polkit']).read()
    assert config == (root / 'port/device-samsung-gta4l/polkit.confd').read_bytes()
    assert b'command_user="polkitd:polkitd"' in config

paths = [root / 'artifacts/apks' / name for name in names] + [root / 'port/device-samsung-gta4l/polkit.confd']
checks = '\n'.join(hashlib.sha256(path.read_bytes()).hexdigest() + '  /tmp/gta4l-upload/' + path.name for path in paths)
old_script = (root / 'tools/live-polkit-log-permissions-fix.sh').read_text()
old = re.search(r"cat > /etc/conf.d/polkit <<'EOF'\n(.*?)\nEOF", old_script, re.S).group(1) + '\n'
old_hash = hashlib.sha256(old.encode()).hexdigest()
new_hash = hashlib.sha256(config).hexdigest()
packages = ' '.join('/tmp/gta4l-upload/' + name for name in names)
script = f'''#!/bin/sh
set -eu
expected={report['boot_sha256']}
boot_hash() {{ head -c {report['boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
test -f /etc/conf.d/polkit
test ! -L /etc/conf.d/polkit
current=$(sha256sum /etc/conf.d/polkit | cut -d' ' -f1)
case "$current" in {old_hash}|{new_hash}) ;; *) echo 'Unrecognized Polkit configuration; refusing overwrite' >&2; exit 1;; esac
apk --no-network --no-interactive --no-scripts add {packages}
install -m 0644 /tmp/gta4l-upload/polkit.confd /etc/conf.d/polkit
rc-update -q add gta4l-wlan default
/usr/libexec/rc/bin/rc-depend -u
rc-service gta4l-wlan start
[ "$(boot_hash)" = "$expected" ]
echo 'Automatic WLAN startup and Polkit configuration installed; existing boot image verified unchanged.'
'''
(root / 'tools/live-install-wlan-startup-r13.sh').write_text(script, newline='\n')
verification = dict(package_names=names, initializer_sha256=hashlib.sha256(elf).hexdigest(),
                    package_sha256={path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
                    arm64_elf_verified=True, runtime_boot_verified=False,
                    kernel_boot_sha256=report['boot_sha256'])
(root / 'artifacts/wlan-startup-r13-verification.json').write_text(json.dumps(verification, indent=2) + '\n')
print('Verified local ARM64 initializer, service ordering, and Polkit configuration; prepared guarded install')
