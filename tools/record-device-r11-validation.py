#!/usr/bin/env python3
"""Save evidence for the tested OpenRC provider ordering change."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
state = (evidence / 'device-r11-normal-boot-state.raw').read_text()
assert '#8-postmarketOS' in state and 'pmos.debug-shell' not in state
for service in ['polkit', 'modemmanager', 'gta4l-dbus-services', 'lightdm']:
    assert re.search(r'^\s*' + service + r'\s+\[\s*started', state, re.M), service
assert 'supervise-daemon modemmanager --start' in state
assert 'sshd.pam: /usr/sbin/sshd.pam [listener]' in state
subsystems = (evidence / 'device-r11-subsystem-summary.raw').read_text()
assert 'bengal-qrd-snd-card' in subsystems and '/Modem/0' in subsystems
assert 'rmnet_ipa0' in subsystems
report = {
    'device_release': 11,
    'kernel': '4.19.300-perf #8-postmarketOS',
    'normal_boot_verified': True,
    'graphical_login_user_confirmed': True,
    'automatic_usb_ssh_verified': True,
    'polkit_and_modemmanager_openrc_started': True,
    'modemmanager_supervised': True,
    'provider_barrier_started': True,
    'automatic_adsp_alsa_card_verified': True,
    'ipa_and_modem_enumeration_verified': True,
    'scope': 'One automatic reboot; this does not establish race-free startup across repeated boots or LTE data service.',
    'evidence': {
        name: hashlib.sha256((evidence / name).read_bytes()).hexdigest()
        for name in ['device-r11-normal-boot-state.raw', 'device-r11-subsystem-summary.raw',
                     'device-r11-order-check.raw', 'device-r11-install.raw']
    },
}
(root / 'artifacts/device-r11-verification.json').write_text(
    json.dumps(report, indent=2) + '\n', newline='\n')
print('Recorded device r11 automatic boot and provider supervision')
