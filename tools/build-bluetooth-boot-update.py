#!/usr/bin/env python3
"""Build kernel #9 boot-only update preserving the verified #8 ramdisk/DTBs."""
from pathlib import Path
import re

workspace = Path(__file__).resolve().parents[1]
source = (workspace/'tools/build-display-boot-update.py').read_text()
changes = {
    "artifacts / 'display-fix'": "artifacts / 'bluetooth-fix'",
    "artifacts / 'hci-fix-verification.json'": "artifacts / 'plane-resume-fix-verification.json'",
    "artifacts / 'boot-hci-fix.img'": "artifacts / 'boot-plane-resume-fix.img'",
    'linux-samsung-gta4l-4.19.300-r3.apk': 'linux-samsung-gta4l-4.19.300-r7.apk',
    'linux-samsung-gta4l-4.19.300-r4.apk': 'linux-samsung-gta4l-4.19.300-r8.apk',
    '#5-postmarketOS': '#9-postmarketOS',
    'boot-display-fix.img': 'boot-bluetooth-fix.img',
    'postmarketOS-SM-T505-OrangeFox-display-fix.zip': 'postmarketOS-SM-T505-OrangeFox-bluetooth-fix.zip',
    'display-fix-verification.json': 'bluetooth-fix-verification.json',
    'DRM refresh kernel': 'Bluetooth networking and input kernel',
    'Display kernel fix boot verified.': 'Bluetooth kernel boot verified.',
    "assert len(new_modules) == 35 and new_modules == old_modules": "assert len(old_modules) == 35 and len(new_modules) == 37\nassert set(old_modules) <= set(new_modules)\nassert any(n.endswith('/bnep.ko') for n in new_modules)\nassert any(n.endswith('/hidp.ko') for n in new_modules)",
    "'all_35_driver_modules_byte_identical': True": "'all_35_previous_module_paths_retained': True, 'module_count': len(new_modules), 'modules_sha256': new_modules, 'bnep_and_hidp_modules_present': True",
}
pattern = re.compile('|'.join(re.escape(key) for key in changes))
source = pattern.sub(lambda match: changes[match.group()], source)
exec(compile(source, str(workspace/'tools/build-display-boot-update.py'), 'exec'))
