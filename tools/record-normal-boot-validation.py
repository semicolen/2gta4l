#!/usr/bin/env python3
"""Record bounded runtime observations supported by captured tablet evidence."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
state = (root / 'evidence/diagnostic-boot-20261009/normal-boot-state.raw').read_text()
assert '#5-postmarketOS' in state
assert 'pmos.debug-shell' not in state
assert 'xfce4-session' in state
assert 'LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"' in state
for name in ('normal-boot', 'display-fix'):
    path = root / f'artifacts/{name}-verification.json'
    report = json.loads(path.read_text())
    report['runtime_verified'] = True
    report['runtime_verification_scope'] = (
        'Physical graphical login confirmed by user; Xfce session captured via SSH; '
        'kernel #5 and packaged identity touch calibration retained after normal boot'
    )
    report['gpu_acceleration_verified'] = False
    if name == 'normal-boot':
        report['automatic_graphical_startup_verified'] = True
        report['automatic_ssh_availability_verified'] = False
    path.write_text(json.dumps(report, indent=2) + '\n', newline='\n')
print('Recorded normal graphical startup; GPU and automatic SSH remain unverified')
