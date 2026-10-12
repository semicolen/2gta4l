#!/usr/bin/env python3
"""Read bounded boot/MBR evidence through recovery ADB; never writes device data."""
from pathlib import Path
import os
import hashlib
import json
import struct
import subprocess

adb = ['adb', '-s', os.environ['GTA4L_ADB_SERIAL']]
out = Path(__file__).resolve().parents[1] / 'evidence/bootloop-20261009'
out.mkdir(parents=True, exist_ok=True)
def read(node, size, count):
    return subprocess.check_output(adb + ['exec-out', 'dd', 'if=' + node, 'bs=' + str(size), 'count=' + str(count), 'status=none'])
boot = read('/dev/block/by-name/boot', 1048576, 32)
assert len(boot) == 32 * 1048576 and boot.startswith(b'ANDROID!')
(out / 'installed-boot-prefix.img').write_bytes(boot)
mbr = read('/dev/block/by-name/userdata', 512, 1)
assert len(mbr) == 512
(out / 'userdata-mbr.bin').write_bytes(mbr)
parts = []
for n in range(4):
    entry = mbr[446 + n*16:462 + n*16]
    start, sectors = struct.unpack_from('<II', entry, 8)
    parts.append(dict(index=n+1, type=entry[4], bootable=entry[0] == 0x80,
                      start_sector=start, sectors=sectors))
expected = (out.parents[1] / 'artifacts/boot.img').read_bytes()
report = dict(boot_prefix_bytes=len(boot), boot_matches_built_image=boot[:len(expected)] == expected,
              built_boot_sha256=hashlib.sha256(expected).hexdigest(),
              userdata_mbr_valid=mbr[510:512] == b'\x55\xaa', partitions=parts)
(out / 'installed-image.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
