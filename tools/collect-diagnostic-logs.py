#!/usr/bin/env python3
"""Collect diagnostic boot logs through read-only OrangeFox inspection."""
from pathlib import Path
import os
import hashlib
import json
import struct
import subprocess

workspace = Path(__file__).resolve().parents[1]
out = workspace / 'evidence/diagnostic-boot-20261009/system-boot'
out.mkdir(parents=True, exist_ok=True)
adb = ['adb', '-s', os.environ['GTA4L_ADB_SERIAL']]

def capture(*args):
    return subprocess.check_output(adb + list(args))

assert capture('get-state').strip() == b'recovery'
assert capture('shell', 'getprop', 'ro.product.device').strip() == b'gta4l'
assert capture('shell', 'id', '-u').strip() == b'0'
mbr = capture('exec-out', 'dd', 'if=/dev/block/by-name/userdata', 'bs=512', 'count=1', 'status=none')
assert len(mbr) == 512 and mbr[-2:] == b'\x55\xaa'
entry = mbr[462:478]
start, sectors = struct.unpack_from('<II', entry, 8)
assert entry[4] == 0x83 and start == 524288
start *= 512
length = sectors * 512
assert 0 < length <= 23484415488 - start
(out / 'userdata-mbr.bin').write_bytes(mbr)
expected = (workspace / 'artifacts/boot-diagnostic.img').read_bytes()
boot = capture('exec-out', 'dd', 'if=/dev/block/by-name/boot', 'bs=1048576', 'count=32', 'status=none')
assert len(boot) == 32 * 1048576
matches = boot[:len(expected)] == expected
(out / 'recovery-cmdline.txt').write_bytes(capture('shell', 'cat', '/proc/cmdline'))
pstore = subprocess.run(adb + ['pull', '/sys/fs/pstore', str(out / 'pstore')], check=False)
hashes = subprocess.run(adb + ['shell', 'sha256sum /sys/fs/pstore/*'],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
(out / 'pstore-sha256.txt').write_bytes(hashes.stdout)
(out / 'pstore-state.txt').write_bytes(hashes.stderr)
subprocess.run(adb + ['push', str(workspace / 'tools/read-rootfs-logs.sh'), '/tmp/gta4l-read-rootfs-logs.sh'], check=True)
subprocess.run(adb + ['shell', 'sh', '/tmp/gta4l-read-rootfs-logs.sh', str(start), str(length)], check=True)
subprocess.run(adb + ['pull', '/tmp/gta4l-bootloop-evidence', str(out / 'rootfs')], check=True)
subprocess.run(adb + ['pull', '/tmp/recovery.log', str(out / 'recovery.log')], check=True)
report = dict(installed_diagnostic_boot_matches=matches,
              expected_boot_sha256=hashlib.sha256(expected).hexdigest(),
              rootfs_start_bytes=start, rootfs_length_bytes=length,
              rootfs_read_mode='read-only loop, ext4 ro,noload',
              physical_partition_writes=False, pstore_pull_exit=pstore.returncode,
              persistent_gta4l_logs_present=any((out / 'rootfs/gta4l').glob('kernel-live.log*')))
(out / 'collection.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
