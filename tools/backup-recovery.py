#!/usr/bin/env python3
"""Read device partitions into local files while OrangeFox is running."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--serial', required=True)
args = parser.parse_args()
adb = ['adb', '-s', args.serial]
def query(*command):
    return subprocess.check_output(adb + ['shell', *command], text=True).strip()
if query('id', '-u') != '0':
    raise SystemExit('Boot OrangeFox first. Root ADB is required for partition backups.')
device = query('getprop', 'ro.product.device')
bootloader = query('getprop', 'ro.bootloader')
model = query('getprop', 'ro.product.model')
if device != 'gta4l' or not (bootloader.startswith('T505') or model in ('SM-T505', 'SM_T505')):
    raise SystemExit(f'Device check failed: {device}, {model}, {bootloader}')
out = Path(__file__).resolve().parents[1] / 'artifacts/backups' / time.strftime('%Y%m%d-%H%M%S')
out.mkdir(parents=True)
report = {'model': model, 'device': device, 'bootloader': bootloader, 'partitions': {}}
for name in ['boot', 'recovery', 'dtbo', 'vbmeta', 'vbmeta_samsung', 'efs', 'sec_efs', 'modemst1', 'modemst2', 'persist']:
    node = '/dev/block/by-name/' + name
    expected = int(query('blockdev', '--getsize64', node))
    if expected <= 0 or expected > 128 * 1024 * 1024:
        raise SystemExit(f'Unexpected partition size: {name}: {expected}')
    dest = out / (name + '.img')
    with dest.open('wb') as handle:
        subprocess.run(adb + ['exec-out', 'cat', node], stdout=handle, check=True)
    if dest.stat().st_size != expected:
        raise SystemExit(f'Incomplete backup: {name}')
    report['partitions'][name] = {'bytes': expected, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
    print('Backed up', name, expected, 'bytes', flush=True)
(out / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(out)
