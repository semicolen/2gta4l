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
parser.add_argument('--root',type=Path)
parser.add_argument('--ui',default='xfce4')
args=parser.parse_args()
build = Path('/home/ark/sm-t505-port/work')
root = args.root or build / 'chroot_rootfs_samsung-gta4l'
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
            'bluetooth', 'gta4l-bluetooth', 'gta4l-tqftpserv', 'gta4l-wlan', 'networkmanager',
            'gta4l-sensors','iio-sensor-proxy','gta4l-camera']
profiles=json.loads((workspace/'ui-profiles/profiles.json').read_text())
assert args.ui in profiles,args.ui
profile=profiles[args.ui]
services.append(profile['display_manager'])
records={}
for section in (root/'lib/apk/db/installed').read_text().split('\n\n'):
    values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if 'P' in values:records[values['P']]=values['V']
for package in profile['core_packages']:
    assert package in records,'Missing desktop component: '+package
assert 'openrc' in records and 'postmarketos-base-openrc' in records
assert 'systemd' not in records and 'postmarketos-base-systemd' not in records
assert 'postmarketos-base-ui-audio-backend-pulseaudio' in records
assert 'pipewire-pulse' not in records
assert 'polkit-elogind' in records and 'polkit-elogind-libs' in records
assert 'polkit-noelogind-libs' not in records
if root.is_relative_to(build.parent/'ui-work'):
    services.append('gta4l-gps-assistance')
    assert records['gps-gta4l']=='1.0-r5' and records['modemmanager']=='1.25.95_git20261005-r5'
    assert records['gps-assistance-gta4l']=='1.0-r0' and records['gps-assistance-gta4l-openrc']=='1.0-r0'
    assert records['alsa-ucm-gta4l']=='1.0-r4' and records['alsa-ucm-gta4l-pulseaudio']=='1.0-r4'
    assert (root/'usr/libexec/gta4l-gps-assistance.py').read_bytes()==(workspace/'port/gps-assistance-gta4l/gta4l-gps-assistance.py').read_bytes()
    assert (root/'etc/init.d/gta4l-gps-assistance').read_bytes()==(workspace/'port/gps-assistance-gta4l/gta4l-gps-assistance.initd').read_bytes()
    assert (root/'usr/share/alsa/ucm2/Qualcomm/gta4l/HiFi.conf').read_bytes()==(workspace/'port/alsa-ucm-gta4l/HiFi.conf').read_bytes()
    if args.ui in ('gnome','gnome-mobile','plasma-mobile','plasma-desktop'):
        assert records['camera-pipewire-gta4l']=='1.0-r0'
        assert (root/'usr/libexec/gta4l-camera-pipewire-session').read_bytes()==(workspace/'port/camera-pipewire-gta4l/gta4l-camera-pipewire-session.py').read_bytes()
        assert (root/'etc/wireplumber/wireplumber.conf.d/60-gta4l-camera.conf').read_bytes()==(workspace/'port/camera-pipewire-gta4l/60-gta4l-camera.conf').read_bytes()
    if args.ui in ('gnome','gnome-mobile'):
        import hashlib
        assert records['snapshot']=='51.0-r1'
        camera_audit=json.loads((workspace/'artifacts/snapshot-shutter-r1-audit.json').read_text())
        native=next(p for p in camera_audit['packages'] if p['name']=='snapshot')
        assert camera_audit['hardware_tested_candidate_allocated_code_and_data_identical']
        assert hashlib.sha256((root/native['executable']).read_bytes()).hexdigest()==native['executable_sha256']
    assert records['linux-samsung-gta4l']=='4.19.300-r10'
    assert all(records[name]=='3.9-r4' for name in ('iio-sensor-proxy','iio-sensor-proxy-openrc','iio-sensor-proxy-udev'))
    assert records['camera-gta4l']=='1.0-r5'
    assert 'wayland-utils' in records
    assert (root/'usr/bin/gta4l-camera').read_bytes()==(workspace/'port/camera-gta4l/gta4l-camera.py').read_bytes()
    compat=json.loads((root/'etc/gta4l-ui-compat.json').read_text())
    assert compat['ui']==args.ui and compat['polkit_provider']=='elogind'
    if args.ui in ('plasma-mobile','plasma-desktop'):
        assert (root/'etc/skel/.config/kcminputrc').read_bytes()==(workspace/'ui-profiles/plasma-kcminputrc').read_bytes()
        assert (root/'etc/skel/.config/kwinrc').read_bytes()==(workspace/'ui-profiles/plasma-kwinrc').read_bytes()
    if args.ui in ('plasma-mobile','plasma-desktop','gnome-mobile','gnome'):
        assert (root/'etc/udev/rules.d/82-gta4l-wayland-sensors.rules').read_bytes()==(workspace/'ui-profiles/82-gta4l-wayland-sensors.rules').read_bytes()
    if args.ui in ('gnome','gnome-mobile'):
        assert compat['gnome_touch_calibration'] is True
        assert compat['gnome_adreno_rendering'] is True
        assert compat['gnome_gtk_opengl'] is True
        wrapper=root/'usr/bin/gta4l-gnome-session'
        assert wrapper.read_bytes()==(workspace/'ui-profiles/gta4l-gnome-session').read_bytes()
        assert wrapper.stat().st_uid==0 and wrapper.stat().st_mode & 0o777==0o755
        assert records['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
        assert (root/'etc/profile.d/80-gta4l-rendering.sh').read_bytes()==(workspace/'ui-profiles/gnome-rendering-profile.sh').read_bytes()
        assert (root/'usr/bin/gta4l-zink-run').read_bytes()==(workspace/'port/mesa-zink-kgsl-gta4l/gta4l-zink-run').read_bytes()
        assert (root/'usr/lib/gta4l-zink/lib/libgallium-26.0.8.so').is_file()
        assert 'Exec=/usr/bin/gta4l-zink-run /usr/bin/gta4l-gnome-session' in (root/'usr/share/wayland-sessions/gnome.desktop').read_text()
        assert 'gta4l-zink-run' not in (root/'usr/share/wayland-sessions/gnome-gta4l-software.desktop').read_text()
        assert 'Exec=/usr/bin/gta4l-gnome-session' in (root/'usr/share/wayland-sessions/gnome-gta4l-software.desktop').read_text()
        calibration=root/'etc/udev/rules.d/99-gta4l-gnome-touch.rules'
        assert calibration.read_bytes()==(workspace/'ui-profiles/99-gta4l-gnome-touch.rules').read_bytes()
        assert calibration.stat().st_uid==0 and calibration.stat().st_mode & 0o777 == 0o644
    if args.ui=='plasma-desktop':
        assert records['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
        assert compat['plasma_adreno_rendering'] is True
        assert (root/'etc/profile.d/80-gta4l-rendering.sh').read_bytes()==(workspace/'ui-profiles/plasma-rendering-profile.sh').read_bytes()
        assert (root/'etc/skel/.config/plasma-workspace/env/80-gta4l-zink.sh').read_bytes()==(workspace/'ui-profiles/plasma-zink-environment.sh').read_bytes()
        assert (root/'usr/bin/gta4l-zink-run').read_bytes()==(workspace/'port/mesa-zink-kgsl-gta4l/gta4l-zink-run').read_bytes()
        assert (root/'usr/lib/gta4l-zink/lib/libgallium-26.0.8.so').is_file()
        assert 'Exec=/usr/bin/gta4l-zink-run /usr/lib/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland' in (root/'usr/share/wayland-sessions/plasma.desktop').read_text()
        assert 'gta4l-zink-run' not in (root/'usr/share/wayland-sessions/plasma-gta4l-software.desktop').read_text()
        assert 'Session=/usr/share/wayland-sessions/plasma.desktop' in (root/'var/lib/sddm/state.conf').read_text()
        sddm=next(line.split(':') for line in (root/'etc/passwd').read_text().splitlines() if line.startswith('sddm:'))
        target=root/sddm[5].lstrip('/')/'.config/kcminputrc'
        assert target.read_bytes()==(workspace/'ui-profiles/plasma-kcminputrc').read_bytes()
        assert target.stat().st_uid==int(sddm[2]) and target.stat().st_gid==int(sddm[3])
    if args.ui in ('plasma-mobile','gnome-mobile','gnome'):
        assert not (root/'etc/runlevels/default/usb-signaller').exists()
sessions=root/'usr/share'/('xsessions' if profile['session_type']=='x11' else 'wayland-sessions')
session_files=sorted(str(path.relative_to(root)) for path in sessions.glob('*.desktop'))
assert session_files,'No session descriptors for '+args.ui
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
              ui=args.ui,
              desktop_rendering='Adreno 610 via Zink/Turnip' if args.ui in ('plasma-desktop','gnome','gnome-mobile') else 'software',
              desktop_packages={name:records[name] for name in profile['core_packages']},
              session_descriptors=session_files,
              autoload_modules=loader, touch_initramfs_files=touch,
              enabled_services=services, protection_domain_maps=maps,
              subsystem_helper_lifecycle_check=True,
              audio_interrupt_startup_policy_verified=True,
              checks_passed=True, runtime_verified=False)
args.report.write_text(json.dumps(report, indent=2) + '\n')
print('Validated', len(modules), 'ARM64 driver modules,', len(maps), 'PD maps, and', len(services), 'enabled services')
