#!/usr/bin/env python3
"""Build the guarded TDDI resume update from the installed #6 boot."""
from pathlib import Path
import re

workspace = Path(__file__).resolve().parents[1]
source = (workspace / 'tools/build-display-boot-update.py').read_text()
replacements = {
    "artifacts / 'display-fix'": "artifacts / 'touch-resume-fix'",
    "artifacts / 'hci-fix-verification.json'": "artifacts / 'backlight-fix-verification.json'",
    "artifacts / 'boot-hci-fix.img'": "artifacts / 'boot-backlight-fix.img'",
    'linux-samsung-gta4l-4.19.300-r3.apk': 'linux-samsung-gta4l-4.19.300-r5.apk',
    'linux-samsung-gta4l-4.19.300-r4.apk': 'linux-samsung-gta4l-4.19.300-r6.apk',
    '#5-postmarketOS': '#7-postmarketOS',
    'boot-display-fix.img': 'boot-touch-resume-fix.img',
    'postmarketOS-SM-T505-OrangeFox-display-fix.zip': 'postmarketOS-SM-T505-OrangeFox-touch-resume-fix.zip',
    'display-fix-verification.json': 'touch-resume-fix-verification.json',
    'DRM refresh kernel': 'touch/display resume kernel',
    'Display kernel fix boot verified.': 'Touch/display resume kernel fix boot verified.',
}
pattern = re.compile('|'.join(re.escape(key) for key in replacements))
source = pattern.sub(lambda match: replacements[match.group()], source)
exec(compile(source, str(workspace / 'tools/build-display-boot-update.py'), 'exec'))
