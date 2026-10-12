#!/usr/bin/env python3
"""Replace only the kernel in the verified r3 diagnostic image."""
from pathlib import Path
import gzip
import hashlib
import json
import struct
import subprocess
import zipfile

workspace = Path(__file__).resolve().parents[1]
artifacts = workspace / 'artifacts'
before = (artifacts / 'boot-diagnostic-r3.img').read_bytes()
assert hashlib.sha256(before).hexdigest() == 'f0f9e69fefd4bb9fb96f105c8e910db123ebd4bc4d24de1698c26208332d4dcd'
header = bytearray(before[:4096])
ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', header, 8)
assert page == 4096 and version == 2 and ss == 0
align = lambda value: (value + page - 1) // page * page
rd_start = page + align(ks)
ramdisk = before[rd_start:rd_start + rs]
dtb_start = rd_start + align(rs)
dtb_size, dtb_address = struct.unpack_from('<IQ', header, 1648)
dtb = before[dtb_start:dtb_start + dtb_size]
assert before[dtb_start + align(dtb_size):] == b'SEANDROIDENFORCE'
kernel = (artifacts / 'hci-fix/vmlinuz').read_bytes()
assert kernel[:2] == b'\x1f\x8b'
assert (artifacts / 'hci-fix/gta4l.dtb').read_bytes() == dtb
comparison = json.loads((artifacts / 'hci-fix/package-comparison.json').read_text())
assert comparison['changed_modules'] == [] and comparison['dtb_matches_previous_kernel']
raw_kernel = gzip.decompress(kernel)
assert b'4.19.300-perf' in raw_kernel and b'#4-postmarketOS' in raw_kernel
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
target = artifacts / 'boot-hci-fix.img'
target.write_bytes(image)
image_hash = hashlib.sha256(image).hexdigest()
updater = (workspace / 'diagnostics/update-binary').read_text()
for key, value in {
    '@ORIGINAL_BYTES@': str(len(before)),
    '@ORIGINAL_SHA256@': hashlib.sha256(before).hexdigest(),
    '@DIAGNOSTIC_BYTES@': str(len(image)),
    '@DIAGNOSTIC_SHA256@': image_hash,
}.items():
    updater = updater.replace(key, value)
updater = updater.replace('Boot-only diagnostic update.', 'Boot-only HCI kernel fix with diagnostic logging.')
updater = updater.replace('Installing SM-T505 diagnostic boot;', 'Installing SM-T505 HCI kernel fix;')
updater = updater.replace('Diagnostic boot verified.', 'HCI kernel fix boot verified.')
assert '@' not in updater
temporary = artifacts / 'hci-fix/update-binary'
temporary.write_text(updater, newline='\n')
subprocess.run(['sh', '-n', str(temporary)], check=True)
package = artifacts / 'postmarketOS-SM-T505-OrangeFox-hci-fix.zip'
with zipfile.ZipFile(package, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    info = zipfile.ZipInfo('META-INF/com/google/android/update-binary')
    info.create_system = 3
    info.external_attr = 0o100755 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, updater.encode())
    archive.writestr('boot.img', image)
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    assert archive.read('boot.img') == image
check_header = bytearray(header)
struct.pack_into('<I', check_header, 8, ks)
check_header[576:608] = before[576:608]
assert bytes(check_header) == before[:4096]
report = {
    'build_host': 'WSL Ubuntu',
    'boot_sha256': image_hash,
    'boot_bytes': len(image),
    'package_sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
    'expected_installed_boot_sha256': hashlib.sha256(before).hexdigest(),
    'ramdisk_unchanged': True,
    'dtb_unchanged': True,
    'all_35_driver_modules_byte_identical': True,
    'kernel_package': comparison['kernel_package'],
    'kernel_build_version': '#4-postmarketOS',
    'installer_partition_writes': ['boot'],
    'formats_userdata': False,
    'runtime_verified': False,
}
(artifacts / 'hci-fix-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
