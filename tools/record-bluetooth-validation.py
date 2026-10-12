#!/usr/bin/env python3
"""Record bounded, completed Bluetooth tests without claiming full device support."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
artifacts = root/'artifacts'
evidence = root/'evidence/diagnostic-boot-20261009'
boot = (evidence/'device-r15-bt-normal-boot-check.raw').read_text()
pan = (evidence/'device-r15-bt-pan-internet-check.raw').read_text()
post = (evidence/'device-r15-bt-post-test-state.raw').read_text()
install = (evidence/'device-r15-bluetooth-package-install.raw').read_text()
assert '#9-postmarketOS' in boot and 'BT_AUTOMATIC_BOOT_CHECK_END' in boot
assert 'BT_STOCK_FIRMWARE_AND_ADDRESS_VERIFIED' in boot and 'BT_HCI_CONTROLLER_READY' in boot
assert 'BLUETOOTH_AND_KERNEL9_PACKAGES_INSTALLED_BOOT_UNCHANGED' in install
for protocol in [1, 4, 6]:
    assert f'BLUETOOTH_PROTOCOL_SOCKET_TEST_PASS {protocol}' in boot
assert 'BLUETOOTH_PAN_INTERNET_VERIFIED' in pan
results = [json.loads(line) for line in pan.splitlines() if line.startswith('{')]
assert len(results) == 1
result = results[0]
assert result['interface'] == 'bnep0' and result['dns_bound_to_pan']
assert result['https_bound_to_pan'] and result['tls_certificate_verified']
assert result['http_status'] == 'HTTP/1.1 200 OK'
assert 'RAPOO BT4.0 Mouse' in post and 'GENERAL.STATE:' in post and 'activated' in post
assert post.count('alsa_card.platform-') == 1 and post.count('.HiFi__Speaker__sink') == 1
readback = json.loads((evidence/'bluetooth-fix-readback.json').read_text())
image = json.loads((artifacts/'bluetooth-fix-verification.json').read_text())
assert readback['boot_sha256'] == image['boot_sha256'] and readback['matches_built_image']
boot_id = re.search(r'^([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$', boot, re.M)[1]
names = ['device-r14-bt-mouse-events.raw', 'device-r15-bluetooth-package-install.raw',
         'bluetooth-fix-readback.json', 'device-r15-bt-normal-boot-check.raw',
         'device-r15-bt-lenovo-pan-connect.raw', 'device-r15-bt-pan-internet-check.raw',
         'device-r15-bt-post-test-state.raw']
hashes = {name: hashlib.sha256((evidence/name).read_bytes()).hexdigest() for name in names}
report = {
    'kernel': '#9-postmarketOS', 'kernel_package': '4.19.300-r8', 'device_package': '1-r15',
    'boot_id': boot_id, 'normal_boots_verified': 1,
    'automatic_radio_startup_verified': True,
    'stock_firmware_and_read_only_stock_address_verified': True,
    'raw_socket_tests_per_protocol': {'hci': 10, 'bnep': 10, 'hidp': 10},
    'user_confirmed_after_reboot': ['desktop', 'touch', 'RAPOO mouse pointer and clicks'],
    'pan_profile': 'gta4l-lenovo-pan', 'pan_profile_autoconnect': False,
    'wifi_remains_preferred': True, 'pan_test': result,
    'single_desktop_audio_card_and_sink_present': True,
    'full_installer_rebuilt': False,
    'not_verified': ['physical classic HIDP', 'Bluetooth audio', 'Bluetooth power saving',
                     'system suspend', 'PAN reconnect', 'long transfers'],
    'private_evidence_sha256': hashes,
}
(artifacts/'bluetooth-runtime-verification.json').write_text(json.dumps(report, indent=2)+'\n')
for name in ['bluetooth-fix-verification.json', 'bluetooth-boot-header-verification.json',
             'bluetooth-packages-verification.json']:
    path = artifacts/name
    value = json.loads(path.read_text())
    value['runtime_verified'] = True
    value['runtime_validation_report'] = 'bluetooth-runtime-verification.json'
    value['normal_boots_verified'] = 1
    path.write_text(json.dumps(value, indent=2)+'\n')
checksum_path = artifacts/'SHA256SUMS'
checksums = dict(line.split('  ', 1)[::-1] for line in checksum_path.read_text().splitlines() if line)
new_files = ['boot-bluetooth-fix.img', 'postmarketOS-SM-T505-OrangeFox-bluetooth-fix.zip']
packages = json.loads((artifacts/'bluetooth-packages-verification.json').read_text())['packages_sha256']
new_files.extend('apks/'+name for name in packages)
for name in new_files:
    checksums[name] = hashlib.sha256((artifacts/name).read_bytes()).hexdigest()
checksum_path.write_text(''.join(checksums[name]+'  '+name+'\n' for name in sorted(checksums)))
print('Recorded kernel #9 automatic Bluetooth, mouse confirmation, and PAN DNS/HTTPS; updated artifact checksums.')
