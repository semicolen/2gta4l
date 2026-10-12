#!/usr/bin/env python3
"""Record integrity and limits of the captured recovery/boot evidence."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1] / 'evidence/bootloop-20261009'
device_hashes = (root / 'pstore-sha256.txt').read_text(encoding='utf-8-sig')
checks = {}
for name in ['dmesg-ramoops-0.enc.z', 'pmsg-ramoops-0']:
    data = (root / 'pstore' / name).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    expected = re.search(r'([0-9a-f]{64})\s+/sys/fs/pstore/' + re.escape(name), device_hashes)[1]
    assert digest == expected, name
    checks[name] = dict(bytes=len(data), sha256=digest, matches_device=True)
raw = (root / 'pstore/pmsg-ramoops-0').read_bytes()
(root / 'initramfs-pmsg.txt').write_text(raw.decode('utf-8', errors='replace'), encoding='utf-8')
report = dict(
    device='SM-T505', installed_image=json.loads((root / 'installed-image.json').read_text()),
    pstore_integrity=checks, panic_record_decodable=False,
    readable_initramfs_record_contains_corrupted_bytes=True,
    last_readable_operation='switch_root; initramfs deliberately disables console output',
    user_screenshot_confirms_root_and_boot_mounted=True,
    filesystem_resize_completed=True,
    exact_reset_cause_established=False,
    rootfs_readonly_mount_succeeded=True, persistent_rootfs_boot_logs_present=False,
    filesystem_read_mode='read-only loop and ext4 ro,noload; no journal replay',
    physical_partition_writes_during_collection=False)
(root / 'collection-summary.json').write_text(json.dumps(report, indent=2) + '\n')
print('Saved evidence summary; both pstore file hashes match the device')
