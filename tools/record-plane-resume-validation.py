#!/usr/bin/env python3
"""Record the tested scope of kernel #8 without implying full device support."""
from pathlib import Path
import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument('--desktop-confirmed', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
state = (evidence / 'plane-resume-normal-boot-state.raw').read_text()
assert '#8-postmarketOS' in state and 'pmos.debug-shell' not in state
assert 'sshd.pam: /usr/sbin/sshd.pam [listener]' in state
hci = (evidence / 'plane-resume-hci-regression.raw').read_text()
assert '#8-postmarketOS' in hci and 'PASS: created and closed 10 raw HCI sockets' in hci
dpms = (evidence / 'plane-resume-dpms-test.raw').read_text()
assert 'reconfigure all the parameters' in dpms and 'PLANE_RESUME_TEST_END' in dpms
repeat = (evidence / 'plane-resume-repeat-wake.raw').read_text()
assert 'REPEAT_DISPLAY_WAKE_END' in repeat
assert all(f'Completed off/on cycle: {n} seconds off' in repeat for n in [1, 5, 10])
for name in ['root', 'user']:
    compute = (evidence / f'kernel8-gpu-compute-{name}.raw').read_text()
    assert 'PASS: Adreno GPU computed and returned all 4096 results' in compute
subsystems = (evidence / 'kernel8-subsystem-summary.raw').read_text()
assert 'bengal-qrd-snd-card' in subsystems and '/Modem/0' in subsystems
path = root / 'artifacts/plane-resume-fix-verification.json'
report = json.loads(path.read_text())
readback = json.loads((evidence / 'plane-resume-fix-readback.json').read_text())
assert readback['boot_sha256'] == report['boot_sha256']
report['runtime_verified'] = True
report['runtime_verification_scope'] = (
    'Automatic graphical login and three-second DPMS wake confirmed by user; '
    'unchanged SSPP plane restoration captured; HCI sockets and root/user GPU '
    'compute pass. Three additional wake cycles execute successfully. '
    'This does not establish system suspend or long idle stability.'
)
report['runtime_results'] = {
    'automatic_graphical_login_user_confirmed': True,
    'automatic_ssh_verified': True,
    'three_second_dpms_wake_user_confirmed': True,
    'unchanged_plane_full_programming_captured': True,
    'additional_dpms_off_intervals_seconds': [1, 5, 10],
    'additional_cycles_completed': True,
    'desktop_and_touch_after_additional_cycles_user_confirmed': args.desktop_confirmed,
    'hci_socket_regression_passed': True,
    'root_and_user_gpu_compute_passed': True,
    'automatic_adsp_alsa_enumeration_verified': True,
    'ipa_modem_enumeration_verified': True,
    'modemmanager_openrc_supervision_on_device_r10': False,
    'system_suspend_verified': False,
    'long_idle_verified': False,
}
path.write_text(json.dumps(report, indent=2) + '\n', newline='\n')
print('Recorded kernel #8 physical DPMS wake and bounded driver regressions')
