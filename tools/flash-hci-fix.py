#!/usr/bin/env python3
"""Install the already-validated, boot-only HCI update through OrangeFox."""
from pathlib import Path
import os
import hashlib
import json
import subprocess
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--kind', choices=['hci-fix', 'display-fix', 'normal-boot', 'backlight-fix', 'touch-resume-fix', 'plane-resume-fix', 'bluetooth-fix'], default='hci-fix')
kind = parser.parse_args().kind

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
adb = ['adb', '-s', os.environ['GTA4L_ADB_SERIAL']]
report = json.loads((root / f'artifacts/{kind}-verification.json').read_text())
package = root / f'artifacts/postmarketOS-SM-T505-OrangeFox-{kind}.zip'
assert hashlib.sha256(package.read_bytes()).hexdigest() == report['package_sha256']

def run(*args, **kwargs):
    return subprocess.run(adb + list(args), check=True, timeout=90, **kwargs)

assert run('shell', 'getprop', 'ro.product.device', capture_output=True).stdout.strip() == b'gta4l'
assert run('shell', 'getprop', 'ro.bootloader', capture_output=True).stdout.strip().startswith(b'T505')
assert run('shell', 'blockdev', '--getsize64', '/dev/block/by-name/boot', capture_output=True).stdout.strip() == b'100663296'
before = run('exec-out', 'head', '-c', str(report.get('expected_installed_boot_bytes', 28930064)), '/dev/block/by-name/boot', capture_output=True).stdout
assert hashlib.sha256(before).hexdigest() == report['expected_installed_boot_sha256'], 'Unexpected installed boot; refuse flash'
run('push', str(package), f'/tmp/gta4l-{kind}.zip')
result = run('shell', 'twrp', 'install', f'/tmp/gta4l-{kind}.zip', capture_output=True)
(evidence / f'{kind}-install.log').write_bytes(result.stdout + result.stderr)
after = run('exec-out', 'head', '-c', str(report['boot_bytes']), '/dev/block/by-name/boot', capture_output=True).stdout
assert hashlib.sha256(after).hexdigest() == report['boot_sha256'], 'Readback failed; stay in recovery'
run('pull', '/tmp/recovery.log', str(evidence / f'{kind}-recovery.log'))
(evidence / f'{kind}-readback.json').write_text(json.dumps({
    'serial': os.environ['GTA4L_ADB_SERIAL'],
    'boot_bytes': len(after),
    'boot_sha256': hashlib.sha256(after).hexdigest(),
    'matches_built_image': True,
    'installed_through': 'OrangeFox twrp install',
    'userdata_formatted': False,
}, indent=2) + '\n')
print(f'{kind} boot installed and readback verified; tablet remains in recovery')
