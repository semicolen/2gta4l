#!/usr/bin/env python3
"""Extract audio routing references from the matching local stock image."""
from pathlib import Path
import subprocess
import hashlib
import json

root = Path(__file__).resolve().parents[1]
target = root / 'evidence/stock-audio'
target.mkdir(exist_ok=True)
image = Path('/home/ark/sm-t505-port/stock/vendor/vendor.img')
names = ['mixer_paths_qrd.xml', 'audio_platform_info_qrd.xml',
         'mixer_paths.xml', 'wt_cust_audio.xml']
report = {}
for name in names:
    output = target / name
    # debugfs command arguments are quoted inside its command parser.
    subprocess.run(['/usr/sbin/debugfs', '-R', f'dump /etc/{name} "{output}"', str(image)], check=True)
    assert output.stat().st_size > 1000
    report[name] = hashlib.sha256(output.read_bytes()).hexdigest()
(target / 'SHA256.json').write_text(json.dumps(report, indent=2) + '\n')
print('Extracted matching stock audio route references')
