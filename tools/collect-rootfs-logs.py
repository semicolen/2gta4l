#!/usr/bin/env python3
"""Use the captured MBR to bound a read-only recovery filesystem mount."""
from pathlib import Path
import json
import subprocess

workspace = Path(__file__).resolve().parents[1]
out = workspace / 'evidence/bootloop-20261009'
report = json.loads((out / 'installed-image.json').read_text())
assert report['userdata_mbr_valid']
root = report['partitions'][1]
assert root['type'] == 0x83 and root['start_sector'] == 524288
start = root['start_sector'] * 512
length = root['sectors'] * 512
assert start + length <= 23484415488
adb = ['adb', '-s', 'R9WNC1QG0LJ']
subprocess.run(adb + ['push', str(workspace / 'tools/read-rootfs-logs.sh'), '/tmp/gta4l-read-rootfs-logs.sh'], check=True)
subprocess.run(adb + ['shell', 'sh', '/tmp/gta4l-read-rootfs-logs.sh', str(start), str(length)], check=True)
subprocess.run(adb + ['pull', '/tmp/gta4l-bootloop-evidence', str(out / 'rootfs')], check=True)
