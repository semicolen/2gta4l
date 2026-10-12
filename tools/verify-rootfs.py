#!/usr/bin/env python3
"""Validate packaged driver/runtime prerequisites without device access."""
from pathlib import Path
import json
import subprocess
import select
import argparse

workspace = Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--report',type=Path,default=workspace/'artifacts/rootfs-verification.json')
args=parser.parse_args()
build = Path('/home/pmos/sm-t505-port/work')
root = build / 'chroot_rootfs_samsung-gta4l'
versions = list((root / 'lib/modules').iterdir())
assert len(versions) == 1, 'Unexpected kernel module versions'
version = versions[0].name
assert version == '4.19.300-perf', version
modules = sorted(str(p.relative_to(root)) for p in versions[0].rglob('*.ko'))
assert len(modules) >= 30, 'Vendor driver modules missing'
loader = (root / 'etc/modules-load.d/gta4l.conf').read_text().splitlines()
assert any('wlan' in name for name in loader), 'WLAN module not loaded at boot'
assert 'machine_dlkm' in loader, 'Bengal audio machine module missing'
names = {Path(name).stem.replace('-', '_') for name in modules}
assert all(name.replace('-', '_') in names for name in loader), 'Invalid module loader names'
assert (versions[0] / 'modules.dep').is_file(), 'Module dependencies missing'
assert (root / 'boot/boot.img').is_file(), 'Generated boot image missing'
for name in ['adsp.mdt', 'cdsp.mdt', 'modem.mdt', 'wlanmdsp.mbn', 'a610_zap.mdt']:
    assert (root / 'lib/firmware/postmarketos' / name).is_file(), name
touch = (root / 'usr/share/mkinitfs/files/gta4l-touch-firmware.files').read_text().splitlines()
assert touch and all((root / path.lstrip('/')).is_file() for path in touch), 'Touch firmware file list invalid'
services = ['qrtr-ns', 'gta4l-pd-mapper', 'gta4l-rmtfs', 'gta4l-modem',
            'gta4l-adsp', 'gta4l-ipa', 'gta4l-dbus-services', 'modemmanager',
            'bluetooth', 'gta4l-bluetooth', 'gta4l-tqftpserv', 'gta4l-wlan', 'networkmanager', 'lightdm',
            'gta4l-sensors','iio-sensor-proxy','gta4l-camera']
for service in services:
    assert (root / 'etc/init.d' / service).is_file(), 'Missing service: ' + service
    assert (root / 'etc/runlevels/default' / service).is_symlink(), 'Disabled service: ' + service
assert '-P -r' in (root / 'etc/init.d/gta4l-rmtfs').read_text(), 'NV storage must be read-only during bring-up'
assert not (root / 'etc/runlevels/default/tqftpserv').exists(), 'Legacy firmware server must be disabled'
assert 'TQFTPSERV_FW_DIR=/lib/firmware/postmarketos' in (root / 'etc/init.d/gta4l-tqftpserv').read_text()
assert 'command_user="polkitd:polkitd"' in (root / 'etc/conf.d/polkit').read_text()
assert (root / 'usr/bin/wlfw-initialize-gta4l').is_file()
assert (root / 'usr/bin/gta4l-bt-initialize').is_file()
assert all(name in names for name in ['bnep', 'hidp']), 'Bluetooth tethering/input modules missing'
assert list((root / 'usr/lib/NetworkManager').glob('*/libnm-device-plugin-bluetooth.so')), 'NetworkManager Bluetooth plugin missing'
assert (root / 'usr/share/alsa/ucm2/conf.d/bengal-qrd-snd-/bengal-qrd-snd-card.conf').is_file()
audio_profile = (root / 'usr/share/alsa/ucm2/Qualcomm/gta4l/HiFi.conf').read_text()
assert "name='PRI_MI2S_RX Audio Mixer MultiMedia1' on,on" in audio_profile
assert 'PlaybackPCM "hw:${CardId},0"' in audio_profile
audio_policy = (root / 'etc/pulse/default.pa.d/90-gta4l-audio.pa').read_text()
assert 'device_id=bengalqrdsndcar' in audio_policy and 'tsched=no' in audio_policy
assert 'fragments=4 fragment_size=1920' in audio_policy and 'namereg_fail=false' in audio_policy
assert (root / 'usr/lib/udev/rules.d/90-gta4l-audio.rules').read_bytes() == (workspace / 'port/alsa-ucm-gta4l/90-gta4l-audio.rules').read_bytes()
for name in ('usr/bin/gta4l-camera','usr/bin/gta4l-rotate',
             'etc/ModemManager/gta4l-gps-unlock',
             'etc/xdg/autostart/gta4l-rotation.desktop'):
    assert (root/name).is_file(),name
assert not (root/'etc/runlevels/default/gta4l-gps-prepare').exists()
account=next(line.split(':') for line in (root/'etc/passwd').read_text().splitlines()
             if line.startswith('tablet:'))
video=next(line.split(':') for line in (root/'etc/group').read_text().splitlines()
           if line.startswith('video:'))
assert account[3]==video[2] or 'tablet' in video[3].split(','),'Camera client must belong to video group'
maps = subprocess.check_output(['chroot', str(root), '/usr/bin/env',
                               'PD_MAPPER_FW_DIR=/lib/firmware/postmarketos',
                               '/usr/bin/pd-mapper-gta4l', '--check-maps'], text=True).splitlines()
assert maps and any('modem' in line for line in maps), 'Stock modem PD manifests not parsed'
# Exercise lifecycle/signal handling with /dev/null, never a tablet subsystem.
helper = ['chroot', str(root), '/usr/bin/gta4l-subsystem']
assert subprocess.run(helper + ['/etc/os-release'], capture_output=True).returncode == 1, 'Helper must reject regular files'
process = subprocess.Popen(helper + ['/dev/null'], stderr=subprocess.PIPE, text=True)
try:
    readable, _, _ = select.select([process.stderr], [], [], 10)
    assert readable and 'Holding subsystem active' in process.stderr.readline(), 'ARM64 helper failed to start'
    process.terminate()
    assert process.wait(timeout=10) == 0, 'Helper failed graceful shutdown'
finally:
    if process.poll() is None:
        process.kill()
        process.wait(timeout=10)
report = dict(kernel_release=version, module_count=len(modules), modules=modules,
              autoload_modules=loader, touch_initramfs_files=touch,
              enabled_services=services, protection_domain_maps=maps,
              subsystem_helper_lifecycle_check=True,
              audio_interrupt_startup_policy_verified=True,
              checks_passed=True, runtime_verified=False)
args.report.write_text(json.dumps(report, indent=2) + '\n')
print('Validated', len(modules), 'ARM64 driver modules,', len(maps), 'PD maps, and', len(services), 'enabled services')
