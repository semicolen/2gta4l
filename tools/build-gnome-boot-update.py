#!/usr/bin/env python3
"""Create a guarded boot-only candidate while preserving verified baselines."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import struct
import subprocess
import tarfile
import zipfile

workspace = Path(__file__).resolve().parents[1]
artifacts = workspace / 'artifacts'
parser = argparse.ArgumentParser()
parser.add_argument('--candidate', choices=('gnome', 'file-access'), default='gnome')
args = parser.parse_args()
file_access = args.candidate == 'file-access'
tag = 'file-access-kernel-fix' if file_access else 'gnome-kernel-fix'
build_version = '#11-postmarketOS' if file_access else '#10-postmarketOS'
old_revision, new_revision = (9, 10) if file_access else (8, 9)
output = artifacts / tag
output.mkdir(exist_ok=True)
sha = lambda data: hashlib.sha256(data).hexdigest()
previous_name = 'gnome-kernel-fix-verification.json' if file_access else 'bluetooth-fix-verification.json'
previous = json.loads((artifacts / previous_name).read_text())
before = (artifacts / ('boot-gnome-kernel-fix.img' if file_access else 'boot-current.img')).read_bytes()
expected = ('27deb97480767c3420d97c88b599486abd1b86bbe297527a4e7a7bab61ccedd4' if file_access else
            '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663')
assert sha(before) == previous['boot_sha256'] == expected
if file_access:
    assert previous['runtime_verified']
assert len(before) == previous['boot_bytes'] == 28938256

def package_data(path):
    selected, modules = {}, {}
    with tarfile.open(path, 'r:gz', ignore_zeros=True) as archive:
        for member in archive:
            name = member.name.lstrip('./')
            if member.isfile() and (name in {'boot/vmlinuz', 'boot/dtbs/qcom/gta4l.dtb'} or name.endswith('.ko')):
                data = archive.extractfile(member).read()
                if name.endswith('.ko'):
                    modules[name] = sha(data)
                else:
                    selected[name] = data
    return selected, modules

old_package = artifacts / f'apks/linux-samsung-gta4l-4.19.300-r{old_revision}.apk'
new_package = artifacts / f'apks/linux-samsung-gta4l-4.19.300-r{new_revision}.apk'
old, old_modules = package_data(old_package)
new, new_modules = package_data(new_package)
assert len(new_modules) == 37 and new_modules == old_modules == previous['modules_sha256']
dtb_name = 'boot/dtbs/qcom/gta4l.dtb'
assert new[dtb_name] == old[dtb_name]
kernel = new['boot/vmlinuz']
assert build_version.encode() in gzip.decompress(kernel)
header = bytearray(before[:4096])
ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', header, 8)
assert page == 4096 and version == 2 and ss == 0
align = lambda n: (n + page - 1) // page * page
assert before[page:page + ks] == old['boot/vmlinuz']
rd_start = page + align(ks)
ramdisk = before[rd_start:rd_start + rs]
dtb_start = rd_start + align(rs)
dtb_size, dtb_address = struct.unpack_from('<IQ', header, 1648)
dtb = before[dtb_start:dtb_start + dtb_size]
assert dtb == new[dtb_name]
assert before[dtb_start + align(dtb_size):] == b'SEANDROIDENFORCE'
digest = hashlib.sha1()
for data in (kernel, ramdisk, b'', b'', dtb):
    digest.update(data)
    digest.update(struct.pack('<I', len(data)))
struct.pack_into('<I', header, 8, len(kernel))
header[576:608] = digest.digest() + bytes(12)
image = bytes(header) + kernel + bytes(align(len(kernel)) - len(kernel))
image += ramdisk + bytes(align(len(ramdisk)) - len(ramdisk))
image += dtb + bytes(align(len(dtb)) - len(dtb)) + b'SEANDROIDENFORCE'
assert len(image) < 100663296
new_rd_start = page + align(len(kernel))
assert image[new_rd_start:new_rd_start + rs] == ramdisk
assert image[new_rd_start + align(rs):new_rd_start + align(rs) + dtb_size] == dtb
(artifacts / f'boot-{tag}.img').write_bytes(image)
updater = (workspace / 'diagnostics/update-binary').read_text()
for key, value in {
    '@ORIGINAL_BYTES@': str(len(before)),
    '@ORIGINAL_SHA256@': sha(before),
    '@DIAGNOSTIC_BYTES@': str(len(image)),
    '@DIAGNOSTIC_SHA256@': sha(image),
}.items():
    updater = updater.replace(key, value)
description = 'filesystem access-check' if file_access else 'GNOME input and child-wait'
updater = updater.replace('Boot-only diagnostic update.', f'Boot-only {description} kernel update.')
updater = updater.replace('Installing SM-T505 diagnostic boot;', 'Installing SM-T505 GNOME kernel fix;')
updater = updater.replace('Diagnostic boot verified.', 'GNOME kernel fix boot verified.')
assert '@' not in updater
(output / 'update-binary').write_text(updater, newline='\n')
subprocess.run(['sh', '-n', str(output / 'update-binary')], check=True)
package = artifacts / f'postmarketOS-SM-T505-OrangeFox-{tag}.zip'
with zipfile.ZipFile(package, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    info = zipfile.ZipInfo('META-INF/com/google/android/update-binary')
    info.create_system = 3
    info.external_attr = 0o100755 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, updater.encode())
    archive.writestr('boot.img', image)
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None and archive.read('boot.img') == image
report = {
    'build_host': 'WSL Ubuntu',
    'boot_sha256': sha(image), 'boot_bytes': len(image),
    'package_sha256': sha(package.read_bytes()),
    'expected_installed_boot_sha256': sha(before), 'expected_installed_boot_bytes': len(before),
    'ramdisk_unchanged': True, 'dtb_unchanged': True,
    'module_count': len(new_modules), 'all_driver_modules_byte_identical': True,
    'modules_sha256': new_modules,
    'kernel_package': new_package.name, 'kernel_package_sha256': sha(new_package.read_bytes()),
    'kernel_build_version': build_version,
    'boot_filename': f'boot-{tag}.img', 'package_filename': package.name,
    'installer_partition_writes': ['boot'], 'formats_userdata': False, 'runtime_verified': False,
}
(artifacts / f'{tag}-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k:v for k,v in report.items() if k != 'modules_sha256'}, indent=2))
