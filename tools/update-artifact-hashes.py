#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
artifacts = root / 'artifacts'
report_path = artifacts / 'hci-fix-verification.json'
report = json.loads(report_path.read_text())
test = (root / 'evidence/diagnostic-boot-20261009/hci-fix-socket-test.raw').read_bytes()
assert b'PASS: created and closed 10 raw HCI sockets' in test
assert b'#4-postmarketOS' in test
report['runtime_verified'] = True
report['runtime_verification_scope'] = 'Original HCI socket panic regression and staged OpenRC default startup'
report['bluetooth_radio_verified'] = False
report['unattended_startup_verified'] = False
report_path.write_text(json.dumps(report, indent=2) + '\n')
manifest = artifacts / 'SHA256SUMS'
entries = {}
for line in manifest.read_text().splitlines():
    if line:
        digest, name = line.split('  ', 1)
        entries[name] = digest
paths = list(artifacts.glob('boot-diagnostic-r*.img'))
paths += list(artifacts.glob('postmarketOS-SM-T505-OrangeFox-diagnostic-boot-r*.zip'))
paths += [artifacts / 'boot-hci-fix.img', artifacts / 'postmarketOS-SM-T505-OrangeFox-hci-fix.zip']
paths += [artifacts / 'boot-display-fix.img', artifacts / 'postmarketOS-SM-T505-OrangeFox-display-fix.zip']
paths += [artifacts / 'boot-normal-boot.img', artifacts / 'postmarketOS-SM-T505-OrangeFox-normal-boot.zip']
paths += [artifacts / 'boot-backlight-fix.img', artifacts / 'postmarketOS-SM-T505-OrangeFox-backlight-fix.zip']
paths += [artifacts / 'boot-touch-resume-fix.img', artifacts / 'postmarketOS-SM-T505-OrangeFox-touch-resume-fix.zip']
paths += list(artifacts.glob('boot-plane-resume-fix.img'))
paths += list(artifacts.glob('postmarketOS-SM-T505-OrangeFox-plane-resume-fix.zip'))
paths += list((artifacts / 'apks').glob('*.apk'))
for path in paths:
    entries[path.relative_to(artifacts).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
manifest.write_text(''.join(f'{value}  {name}\n' for name, value in sorted(entries.items())), newline='\n')
print('Recorded bounded runtime HCI validation and updated artifact hashes')
