#!/usr/bin/env python3
"""Validate the local Bluetooth APK set and prepare a boot-preserving upgrade."""
from pathlib import Path
import gzip
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
files = [
    'bluetooth-gta4l-1.0-r0.apk',
    'device-samsung-gta4l-1-r15.apk',
    'device-samsung-gta4l-openrc-1-r15.apk',
    'device-samsung-gta4l-nonfree-firmware-1-r15.apk',
    'linux-samsung-gta4l-4.19.300-r8.apk',
]
hashes = {}
contents = {}
for filename in files:
    path = root/'artifacts/apks'/filename
    hashes[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    members = {}
    with tarfile.open(path, 'r:gz', ignore_zeros=True) as archive:
        for member in archive:
            if member.isfile():
                name = member.name.removeprefix('./')
                members[name] = archive.extractfile(member).read()
    metadata = dict(line.split(' = ', 1) for line in members['.PKGINFO'].decode().splitlines()
                    if ' = ' in line and not line.startswith('#'))
    assert filename == metadata['pkgname']+'-'+metadata['pkgver']+'.apk'
    expected_arch = 'noarch' if metadata['pkgname'] == 'device-samsung-gta4l-openrc' else 'aarch64'
    assert metadata['arch'] == expected_arch
    contents[filename] = members

bt = contents[files[0]]
assert bt['usr/bin/gta4l-bt-initialize'] == (root/'port/bluetooth-gta4l/gta4l-bt-initialize.py').read_bytes()
assert bt['etc/init.d/gta4l-bluetooth'] == (root/'port/bluetooth-gta4l/gta4l-bluetooth.initd').read_bytes()
assert b'depend = networkmanager-bluetooth\n' in contents[files[1]]['.PKGINFO']
assert b'depend = bluetooth-gta4l\n' in contents[files[2]]['.PKGINFO']
modules = [name for name in contents[files[-1]] if name.endswith('.ko')]
assert len(modules) == 37
assert any(name.endswith('/bnep.ko') for name in modules)
assert any(name.endswith('/hidp.ko') for name in modules)
kernel = gzip.decompress(contents[files[-1]]['boot/vmlinuz'])
assert b'#9-postmarketOS' in kernel
start = kernel.index(b'IKCFG_ST')+8
end = kernel.index(b'IKCFG_ED', start)
config = gzip.decompress(kernel[start:end]).decode()
required = {'BT_BNEP': 'm', 'BT_BNEP_MC_FILTER': 'y', 'BT_BNEP_PROTO_FILTER': 'y',
            'BT_HIDP': 'm', 'HIDRAW': 'y', 'UHID': 'y', 'BT_HCIUART_H4': 'y'}
for name, value in required.items():
    assert 'CONFIG_'+name+'='+value+'\n' in config, name
previous = json.loads((root/'artifacts/plane-resume-fix-verification.json').read_text())
script = '#!/bin/sh\nset -eu\n'
script += 'boot_hash() { head -c '+str(previous['boot_bytes'])+' /dev/mmcblk0p69 | sha256sum | cut -d\' \' -f1; }\n'
script += '[ "$(boot_hash)" = \''+previous['boot_sha256']+'\' ]\n'
script += "sha256sum -c - <<'HASHES'\n"
script += ''.join(hashes[name]+'  /tmp/gta4l-upload/'+name+'\n' for name in files)
script += 'HASHES\n'
script += 'apk info -e python3 bluez e2fsprogs-extra firmware-samsung-gta4l alsa-ucm-gta4l networkmanager-bluetooth\n'
script += 'apk --no-network --no-interactive --no-scripts add '+' '.join('/tmp/gta4l-upload/'+name for name in files)+'\n'
script += 'rc-update -q add gta4l-bluetooth default\n/usr/libexec/rc/bin/rc-depend -u\n'
script += '[ "$(boot_hash)" = \''+previous['boot_sha256']+'\' ]\n'
script += 'echo BLUETOOTH_AND_KERNEL9_PACKAGES_INSTALLED_BOOT_UNCHANGED\n'
(root/'tools/live-install-bluetooth-r15.sh').write_text(script, newline='\n')
report = {'build_host': 'WSL Ubuntu', 'packages_sha256': hashes,
          'source_matches_bluetooth_apk': True, 'driver_module_count': len(modules),
          'bnep_and_hidp_modules_present': True, 'verified_kernel_config': required,
          'runtime_verified': False}
(root/'artifacts/bluetooth-packages-verification.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
