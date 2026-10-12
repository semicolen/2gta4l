#!/usr/bin/env python3
"""Record kernel #7's bounded successes and the user-observed wake failure."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
state = (evidence / 'touch-resume-normal-boot-state.raw').read_text()
assert '#7-postmarketOS' in state and 'pmos.debug-shell' not in state
assert 'gta4l-adsp' in state and 'sshd.pam: /usr/sbin/sshd.pam [listener]' in state
hci = (evidence / 'touch-resume-hci-regression.raw').read_text()
assert '#7-postmarketOS' in hci and 'PASS: created and closed 10 raw HCI sockets' in hci
subsystems = (evidence / 'kernel7-subsystem-summary.raw').read_text()
assert 'bengal-qrd-snd-card' in subsystems and '/Modem/0' in subsystems
for name in ('root', 'user'):
    compute = (evidence / f'kernel7-gpu-compute-{name}.raw').read_text()
    assert 'PASS: Adreno GPU computed and returned all 4096 results' in compute
compare = (evidence / 'dpms-modeset-compare.raw').read_text()
assert 'GTA4L_MODESET_COMPARE_DPMS_END' in compare
assert 'GTA4L_MODESET_COMPARE_FULL_MODESET_END' in compare
path = root / 'artifacts/touch-resume-fix-verification.json'
report = json.loads(path.read_text())
report['runtime_verified'] = False
report['runtime_results'] = {
    'automatic_graphical_login_user_confirmed': True,
    'automatic_ssh_verified': True,
    'hci_socket_regression_passed': True,
    'automatic_adsp_alsa_enumeration_verified': True,
    'automatic_ipa_modem_enumeration_verified': True,
    'root_and_user_gpu_compute_passed': True,
    'firmware_resume_precedes_lcd_initialization': True,
    'dpms_resume_user_confirmed': False,
    'full_modeset_restores_screen_user_confirmed': True,
    'greeter_restart_restores_screen_user_confirmed': True,
}
report['runtime_verification_scope'] = (
    'Automatic boot and bounded driver regressions pass; synchronous touch reload '
    'ordering is confirmed but physical DPMS wake still fails. Full modeset and '
    'greeter restart restore the screen. No claim of a successful resume fix.'
)
path.write_text(json.dumps(report, indent=2) + '\n', newline='\n')
print('Recorded kernel #7 boot/driver successes and physical DPMS resume failure')
