#!/usr/bin/env python3
"""Record bounded Wi-Fi results from saved device evidence."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
for release in (12, 13):
    ping = (evidence / f'device-r{release}-wifi-connectivity-test.raw').read_text()
    https = (evidence / f'device-r{release}-wifi-https-clock.raw').read_text()
    assert 'Wi-Fi interface wlan0' in ping
    assert 'wifi_ip_ping_status=0' in ping and 'wifi_dns_ping_status=0' in ping
    assert ping.count('3 packets transmitted, 3 packets received, 0% packet loss') == 2
    assert 'Interface: wlan0' in https and 'WIFI_HTTPS_VERIFIED' in https
    assert 'certificate verification enabled' in https and 'wifi_https_python_status=0' in https
boot = (evidence / 'device-r13-wlan-normal-boot-check.raw').read_text()
assert '#8-postmarketOS' in boot
assert 'WLFW_INITIALIZATION_READY' in boot and 'GTA4L_WLAN_INTERFACE_READY' in boot
assert 'Chip ID 0x150, family 0x4002' in boot
assert 'segment 4, cumulative 26328 bytes' in boot
assert 'supervise-daemon polkit' in boot and 'supervise-daemon modemmanager' in boot
profile = (evidence / 'device-r13-wifi-profile-flags.raw').read_text()
assert 'wlan0           wifi      connected' in profile
assert '=== Current desktop state ===\nDEVICE' in profile, 'Expected reconnect at login screen'
install = (evidence / 'device-r13-wlan-startup-install.raw').read_text()
assert 'existing boot image verified unchanged' in install
report_path = root / 'artifacts/wlan-startup-r13-verification.json'
report = json.loads(report_path.read_text())
report.update(runtime_boot_verified=True, runtime_results=dict(
    automatic_wlfw_board_data_initialization=True,
    firmware_ready_and_wlan0_created=True,
    matching_chip_and_stock_bdf_verified=True,
    automatic_saved_network_reconnect_before_login=True,
    authenticated_wifi_dhcp_dns_verified=True,
    wifi_bound_ip_and_hostname_ping_packet_loss_percent=0,
    certificate_validated_https_over_wlan0=True,
    automatic_clock_synchronization_observed=True,
    polkit_and_modemmanager_supervised_on_normal_boot=True,
    desktop_touch_and_keyboard_after_reboot_user_confirmed=True,
    reboot_tests=1,
    stock_mac_provisioning_verified=False,
    suspend_resume_verified=False,
    firmware_restart_recovery_verified=False,
    sustained_throughput_verified=False,
    complete_device_port_verified=False))
sources = [p for p in evidence.glob('device-r13-w*.raw')]
report['evidence_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources)}
report_path.write_text(json.dumps(report, indent=2) + '\n')
manifest = root / 'artifacts/SHA256SUMS'
entries = dict(line.split('  ', 1)[::-1] for line in manifest.read_text().splitlines() if line)
for path in (root / 'artifacts/apks').glob('*.apk'):
    entries[path.relative_to(root / 'artifacts').as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
manifest.write_text(''.join(f'{digest}  {name}\n' for name, digest in sorted(entries.items())), newline='\n')
print('Recorded normal-boot WLAN initialization, reconnect, DHCP, DNS, Wi-Fi-bound ping/HTTPS, and user-confirmed desktop results')
