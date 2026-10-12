#!/usr/bin/env python3
"""Read a gzip/newc initramfs and verify early touchscreen firmware inclusion."""
from pathlib import Path
import gzip
import json
import argparse

workspace = Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--report',type=Path,default=workspace/'artifacts/initramfs-verification.json')
args=parser.parse_args()
root = Path('/home/pmos/sm-t505-port/work/chroot_rootfs_samsung-gta4l')
data = gzip.decompress((root / 'boot/initramfs').read_bytes())
entries = {}
offset = 0
while offset < len(data):
    if data[offset:offset+6] == b'\0' * 6:
        break
    header = data[offset:offset+110]
    assert header[:6] in (b'070701', b'070702'), 'Unsupported initramfs CPIO'
    values = [int(header[6+i*8:14+i*8], 16) for i in range(13)]
    size, name_size = values[6], values[11]
    offset += 110
    name = data[offset:offset+name_size-1].decode().lstrip('./')
    offset = (offset + name_size + 3) // 4 * 4
    if name == 'TRAILER!!!':
        break
    entries[name] = data[offset:offset+size]
    offset = (offset + size + 3) // 4 * 4
touch = (root / 'usr/share/mkinitfs/files/gta4l-touch-firmware.files').read_text().splitlines()
for filename in touch:
    key = filename.lstrip('/')
    if key not in entries and key.startswith('lib/') and entries.get('lib') in (b'usr/lib', b'/usr/lib'):
        key = 'usr/' + key
    assert entries.get(key) == (root / key).read_bytes(), 'Missing/wrong early firmware: ' + key
assert 'init' in entries, 'Initramfs init missing'
report = dict(compression='gzip', archive_format='newc', entry_count=len(entries),
              touch_firmware_count=len(touch), checks_passed=True, runtime_verified=False)
args.report.write_text(json.dumps(report, indent=2) + '\n')
print('Verified', len(touch), 'touch firmware files inside the gzip initramfs')
