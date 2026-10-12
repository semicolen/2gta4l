#!/usr/bin/env python3
"""Reuse the validated boot builder for the backlight kernel repair."""
from pathlib import Path

workspace = Path(__file__).resolve().parents[1]
source = (workspace / 'tools/build-display-boot-update.py').read_text()
replacements = {
    "artifacts / 'display-fix'": "artifacts / 'backlight-fix'",
    "artifacts / 'hci-fix-verification.json'": "artifacts / 'normal-boot-verification.json'",
    "artifacts / 'boot-hci-fix.img'": "artifacts / 'boot-normal-boot.img'",
    'linux-samsung-gta4l-4.19.300-r3.apk': 'linux-samsung-gta4l-4.19.300-r4.apk',
    'linux-samsung-gta4l-4.19.300-r4.apk': 'linux-samsung-gta4l-4.19.300-r5.apk',
    '#5-postmarketOS': '#6-postmarketOS',
    'boot-display-fix.img': 'boot-backlight-fix.img',
    'postmarketOS-SM-T505-OrangeFox-display-fix.zip': 'postmarketOS-SM-T505-OrangeFox-backlight-fix.zip',
    'display-fix-verification.json': 'backlight-fix-verification.json',
    'DRM refresh kernel': 'backlight kernel',
    'Display kernel fix boot verified.': 'Backlight kernel fix boot verified.',
}
# Apply replacements in one pass so r3->r4 does not also become r5.
import re
pattern = re.compile('|'.join(re.escape(key) for key in replacements))
source = pattern.sub(lambda match: replacements[match.group()], source)
exec(compile(source, str(workspace / 'tools/build-display-boot-update.py'), 'exec'))
