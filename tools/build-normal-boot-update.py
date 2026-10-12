#!/usr/bin/env python3
"""Remove only the debug-shell pause from the tested #5 boot image."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import zipfile

workspace = Path(__file__).resolve().parents[1]
artifacts = workspace / 'artifacts'
output = artifacts / 'normal-boot'
output.mkdir(exist_ok=True)
previous = json.loads((artifacts / 'display-fix-verification.json').read_text())
before = (artifacts / 'boot-display-fix.img').read_bytes()
assert hashlib.sha256(before).hexdigest() == previous['boot_sha256']
image = bytearray(before)
assert image[:8] == b'ANDROID!' and struct.unpack_from('<I', image, 40)[0] == 2
command = bytes(image[64:576]).split(b'\0')[0] + bytes(image[608:1632]).split(b'\0')[0]
assert command.split().count(b'pmos.debug-shell') == 1
after_command = b' '.join(token for token in command.split() if token != b'pmos.debug-shell')
assert len(after_command) < 1536
image[64:576] = after_command[:512].ljust(512, b'\0')
image[608:1632] = after_command[512:].ljust(1024, b'\0')
assert image[4096:] == before[4096:]
assert image[576:608] == before[576:608]
(artifacts / 'boot-normal-boot.img').write_bytes(image)
image_hash = hashlib.sha256(image).hexdigest()
updater = (workspace / 'diagnostics/update-binary').read_text()
for key, value in {
    '@ORIGINAL_BYTES@': str(len(before)),
    '@ORIGINAL_SHA256@': hashlib.sha256(before).hexdigest(),
    '@DIAGNOSTIC_BYTES@': str(len(image)),
    '@DIAGNOSTIC_SHA256@': image_hash,
}.items():
    updater = updater.replace(key, value)
updater = updater.replace('Boot-only diagnostic update.', 'Boot-only automatic startup update.')
updater = updater.replace('Installing SM-T505 diagnostic boot;', 'Installing SM-T505 automatic startup boot;')
updater = updater.replace('Diagnostic boot verified.', 'Automatic startup boot verified.')
assert '@' not in updater
(output / 'update-binary').write_text(updater, newline='\n')
subprocess.run(['sh', '-n', str(output / 'update-binary')], check=True)
package = artifacts / 'postmarketOS-SM-T505-OrangeFox-normal-boot.zip'
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
    'kernel_ramdisk_and_dtb_unchanged': True,
    'kernel_build_version': '#5-postmarketOS',
    'debug_shell_pause_removed': True,
    'persistent_logging_retained': True,
    'installer_partition_writes': ['boot'],
    'formats_userdata': False,
    'runtime_verified': False,
}
(artifacts / 'normal-boot-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
