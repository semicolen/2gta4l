#!/usr/bin/env python3
"""Keep installed APKs and /boot consistent with the verified HCI boot image."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--kind', choices=['hci-fix', 'display-fix'], default='hci-fix')
parser.add_argument('--kernel-release', default='3')
parser.add_argument('--device-release', default='5')
args = parser.parse_args()

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
adb = ['adb', '-s', 'R9WNC1QG0LJ']
report = json.loads((root / f'artifacts/{args.kind}-verification.json').read_text())

def run(*args, **kwargs):
    return subprocess.run(adb + list(args), check=True, timeout=120, **kwargs)

mbr = run('exec-out', 'head', '-c', '512', '/dev/block/by-name/userdata', capture_output=True).stdout
assert mbr[510:512] == b'\x55\xaa'
assert struct.unpack_from('<II', mbr, 454) == (2048, 522240)
assert struct.unpack_from('<II', mbr, 470) == (524288, 45343711)
boot = run('exec-out', 'head', '-c', str(report['boot_bytes']), '/dev/block/by-name/boot', capture_output=True).stdout
assert hashlib.sha256(boot).hexdigest() == report['boot_sha256']
files = [root / f'artifacts/apks/linux-samsung-gta4l-4.19.300-r{args.kernel_release}.apk']
files += sorted((root / 'artifacts/apks').glob(f'device-samsung-gta4l*-r{args.device_release}.apk'))
assert len(files) == 4
run('shell', 'mkdir', '-p', '/tmp/gta4l-package-update')
checksums = []
for file in files:
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    target = '/tmp/gta4l-package-update/' + file.name
    checksums.append(f'{digest}  {target}\n')
    run('push', str(file), target)
manifest = root / f'artifacts/{args.kind}/installed-apk-checksums.txt'
manifest.write_text(''.join(checksums), newline='\n')
run('push', str(manifest), '/tmp/gta4l-package-update.sha256')
run('push', str(root / 'tools/update-installed-kernel.sh'), '/tmp/gta4l-package-update.sh')
result = subprocess.run(adb + ['shell', 'sh', '/tmp/gta4l-package-update.sh'], capture_output=True, timeout=120)
(evidence / f'{args.kind}-root-package-update.log').write_bytes(result.stdout + result.stderr)
result.check_returncode()
assert f'P:linux-samsung-gta4l V:4.19.300-r{args.kernel_release}'.encode() in result.stdout
assert hashlib.sha256((root / f'artifacts/{args.kind}/vmlinuz').read_bytes()).hexdigest().encode() in result.stdout
after = run('exec-out', 'head', '-c', str(report['boot_bytes']), '/dev/block/by-name/boot', capture_output=True).stdout
assert after == boot, 'Package update unexpectedly changed diagnostic boot'
print('Installed APKs and /boot updated; diagnostic HCI boot unchanged')
