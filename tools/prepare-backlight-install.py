#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import argparse

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--kind', choices=['backlight-fix', 'touch-resume-fix', 'plane-resume-fix'], default='backlight-fix')
kind = parser.parse_args().kind
report = json.loads((root / f'artifacts/{kind}-verification.json').read_text())
assert report['all_35_driver_modules_byte_identical'] and report['dtb_unchanged']
package = root / 'artifacts/apks' / report['kernel_package']
digest = hashlib.sha256(package.read_bytes()).hexdigest()
script = f'''#!/bin/sh
set -eu
boot_hash() {{ head -c {report['expected_installed_boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
expected={report['expected_installed_boot_sha256']}
[ "$(boot_hash)" = "$expected" ]
printf '%s\\n' '{digest}  /tmp/gta4l-upload/{package.name}' | sha256sum -c -
echo '=== State before reboot ==='
uname -a
cat /proc/asound/cards 2>/dev/null || true
for state in /sys/bus/msm_subsys/devices/*/state; do
    printf '%s ' "$state"
    cat "$state"
done
dmesg | grep -Ei 'adsp|alsa|asoc|wsa|codec|panic|BUG:' | tail -n 70
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/{package.name}
[ "$(boot_hash)" = "$expected" ]
echo 'Kernel package installed without scripts; existing boot image verified unchanged.'
'''
(root / f'tools/live-install-{kind}-kernel.sh').write_text(script, newline='\n')
print(f'Prepared guarded install of {package.name}: {digest}')
