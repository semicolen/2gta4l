#!/usr/bin/env python3
"""Independently check the diagnostic boot overlay and recovery archive."""
from pathlib import Path
import gzip
import hashlib
import json
import struct
import zipfile
import argparse

workspace = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--revision', type=int, choices=[1, 2, 3], default=1)
args = parser.parse_args()
suffix = '' if args.revision == 1 else f'-r{args.revision}'

def unpack(path):
    data = path.read_bytes()
    kernel_size, _, ramdisk_size = struct.unpack_from('<III', data, 8)
    page = struct.unpack_from('<I', data, 36)[0]
    offset = page + (kernel_size + page - 1) // page * page
    cpio = gzip.decompress(data[offset:offset + ramdisk_size])
    entries = {}
    offset = 0
    while True:
        assert cpio[offset:offset + 6] == b'070701'
        values = [int(cpio[offset + 6 + n*8:offset + 14 + n*8], 16) for n in range(13)]
        name = cpio[offset + 110:offset + 110 + values[11] - 1].decode().removeprefix('./')
        offset = (offset + 110 + values[11] + 3) // 4 * 4
        if name == 'TRAILER!!!':
            break
        assert name not in entries, name
        entries[name] = (values[1], cpio[offset:offset + values[6]])
        offset = (offset + values[6] + 3) // 4 * 4
    return entries

old = unpack(workspace / 'artifacts/boot.img')
new = unpack(workspace / ('artifacts/boot-diagnostic' + suffix + '.img'))
for name, entry in old.items():
    if args.revision == 3 and name == 'init_functions.sh':
        assert new[name][0] == entry[0]
        changed = new[name][1]
        assert changed.count(b'\tif [ ! -e /gta4l-keep-debug-usb ]; then\n') == 1
        restored = changed.replace(b'\tif [ ! -e /gta4l-keep-debug-usb ]; then\n', b'', 1)
        restored = restored.replace(b'\tsetup_usb_configfs_udc\n\tfi\n\n\tsplash_set_message "Loading"', b'\tsetup_usb_configfs_udc\n\n\tsplash_set_message "Loading"', 1)
        assert restored == entry[1], 'Unexpected initramfs function change'
        assert new['gta4l-keep-debug-usb'] == (0o100600, b'')
        continue
    assert new[name] == entry, name
assert new['hooks-cleanup/99-gta4l-diagnostics.sh'] == (
    0o100755, (workspace / 'diagnostics/99-gta4l-diagnostics.sh').read_bytes())
collector = (workspace / 'artifacts/gta4l-bootlog').read_bytes()
assert new['gta4l-bootlog'] == (0o100755, collector)
assert collector[:4] == b'\x7fELF' and struct.unpack_from('<H', collector, 18)[0] == 183
phoff = struct.unpack_from('<Q', collector, 32)[0]
phsize, phnum = struct.unpack_from('<HH', collector, 54)
assert all(struct.unpack_from('<I', collector, phoff + phsize*n)[0] != 3
           for n in range(phnum)), 'Collector must have no ELF interpreter'
with zipfile.ZipFile(workspace / ('artifacts/postmarketOS-SM-T505-OrangeFox-diagnostic-boot' + suffix + '.zip')) as package:
    assert package.testzip() is None
    assert package.read('boot.img') == (workspace / ('artifacts/boot-diagnostic' + suffix + '.img')).read_bytes()
    updater = package.read('META-INF/com/google/android/update-binary').decode()
    assert '@' not in updater
    assert 'mmcblk0p80' not in updater and 'mkfs' not in updater and 'parted' not in updater
    assert updater.count('dd if=') == 1 and 'of="$boot"' in updater
    assert (package.getinfo('META-INF/com/google/android/update-binary').external_attr >> 16) & 0o111
report = dict(original_entries_preserved=len(old) - (args.revision == 3), static_arm64_collector=True,
              overlay_content_and_modes_verified=True, zip_crc_and_embedded_image_verified=True,
              installer_boot_write_only=True,
              collector_sha256=hashlib.sha256(collector).hexdigest())
(workspace / ('artifacts/diagnostic-overlay-check' + suffix + '.json')).write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
