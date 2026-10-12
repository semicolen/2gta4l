#!/usr/bin/env python3
"""Build the guarded display kernel update while preserving diagnostic setup."""
from pathlib import Path
import gzip
import hashlib
import json
import struct
import subprocess
import tarfile
import zipfile

workspace = Path(__file__).resolve().parents[1]
artifacts = workspace / 'artifacts'
output = artifacts / 'display-fix'
output.mkdir(exist_ok=True)
previous = json.loads((artifacts / 'hci-fix-verification.json').read_text())
before = (artifacts / 'boot-hci-fix.img').read_bytes()
assert hashlib.sha256(before).hexdigest() == previous['boot_sha256']

def package_data(path):
    selected, modules = {}, {}
    with tarfile.open(path, 'r:gz', ignore_zeros=True) as archive:
        for member in archive:
            name = member.name.lstrip('./')
            if not member.isfile():
                continue
            if name in {'boot/vmlinuz', 'boot/dtbs/qcom/gta4l.dtb'} or name.endswith('.ko'):
                data = archive.extractfile(member).read()
                if name.endswith('.ko'):
                    modules[name] = hashlib.sha256(data).hexdigest()
                else:
                    selected[name] = data
    return selected, modules

old, old_modules = package_data(artifacts / 'apks/linux-samsung-gta4l-4.19.300-r3.apk')
new, new_modules = package_data(artifacts / 'apks/linux-samsung-gta4l-4.19.300-r4.apk')
assert len(new_modules) == 35 and new_modules == old_modules
assert new['boot/dtbs/qcom/gta4l.dtb'] == old['boot/dtbs/qcom/gta4l.dtb']
kernel = new['boot/vmlinuz']
assert b'#5-postmarketOS' in gzip.decompress(kernel)
header = bytearray(before[:4096])
ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', header, 8)
assert page == 4096 and version == 2 and ss == 0
align = lambda n: (n + page - 1) // page * page
rd_start = page + align(ks)
ramdisk = before[rd_start:rd_start + rs]
dtb_start = rd_start + align(rs)
dtb_size, dtb_address = struct.unpack_from('<IQ', header, 1648)
dtb = before[dtb_start:dtb_start + dtb_size]
assert dtb == new['boot/dtbs/qcom/gta4l.dtb']
assert before[dtb_start + align(dtb_size):] == b'SEANDROIDENFORCE'
digest = hashlib.sha1()
for data in [kernel, ramdisk, b'', b'', dtb]:
    digest.update(data)
    digest.update(struct.pack('<I', len(data)))
struct.pack_into('<I', header, 8, len(kernel))
header[576:608] = digest.digest() + bytes(12)
image = bytes(header) + kernel + bytes(align(len(kernel)) - len(kernel))
image += ramdisk + bytes(align(len(ramdisk)) - len(ramdisk))
image += dtb + bytes(align(len(dtb)) - len(dtb)) + b'SEANDROIDENFORCE'
assert len(image) < 100663296
(artifacts / 'boot-display-fix.img').write_bytes(image)
(output / 'vmlinuz').write_bytes(kernel)
image_hash = hashlib.sha256(image).hexdigest()
updater = (workspace / 'diagnostics/update-binary').read_text()
for key, value in {
    '@ORIGINAL_BYTES@': str(len(before)),
    '@ORIGINAL_SHA256@': hashlib.sha256(before).hexdigest(),
    '@DIAGNOSTIC_BYTES@': str(len(image)),
    '@DIAGNOSTIC_SHA256@': image_hash,
}.items():
    updater = updater.replace(key, value)
updater = updater.replace('Boot-only diagnostic update.', 'Boot-only DRM refresh kernel update.')
updater = updater.replace('Installing SM-T505 diagnostic boot;', 'Installing SM-T505 DRM refresh kernel fix;')
updater = updater.replace('Diagnostic boot verified.', 'Display kernel fix boot verified.')
assert '@' not in updater
(output / 'update-binary').write_text(updater, newline='\n')
subprocess.run(['sh', '-n', str(output / 'update-binary')], check=True)
package = artifacts / 'postmarketOS-SM-T505-OrangeFox-display-fix.zip'
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
    'boot_sha256': image_hash,
    'boot_bytes': len(image),
    'package_sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
    'expected_installed_boot_sha256': hashlib.sha256(before).hexdigest(),
    'expected_installed_boot_bytes': len(before),
    'ramdisk_unchanged': True,
    'dtb_unchanged': True,
    'all_35_driver_modules_byte_identical': True,
    'kernel_package': 'linux-samsung-gta4l-4.19.300-r4.apk',
    'kernel_build_version': '#5-postmarketOS',
    'installer_partition_writes': ['boot'],
    'formats_userdata': False,
    'runtime_verified': False,
}
(artifacts / 'display-fix-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
