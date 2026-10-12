#!/usr/bin/env python3
"""Verify exact package contents and prepare a boot-preserving audio update."""
from pathlib import Path
import hashlib,json,tarfile
root=Path(__file__).resolve().parents[1]
packages=[root/'artifacts/apks'/f'{name}-1.0-r3.apk' for name in ('alsa-ucm-gta4l','alsa-ucm-gta4l-pulseaudio')]
required={
    packages[0]:{'usr/share/alsa/ucm2/Qualcomm/gta4l/gta4l.conf':'gta4l.conf',
                 'usr/share/alsa/ucm2/Qualcomm/gta4l/HiFi.conf':'HiFi.conf'},
    packages[1]:{'usr/lib/udev/rules.d/90-gta4l-audio.rules':'90-gta4l-audio.rules',
                 'etc/pulse/default.pa.d/90-gta4l-audio.pa':'90-gta4l-audio.pa'}}
hashes={}
for package,expected in required.items():
    with tarfile.open(package,'r:gz',ignore_zeros=True) as tar:
        members={member.name.removeprefix('./'):member for member in tar}
        for name,source in expected.items():
            assert tar.extractfile(members[name]).read()==(root/'port/alsa-ucm-gta4l'/source).read_bytes()
        info=tar.extractfile(members['.PKGINFO']).read().decode()
        assert 'pkgver = 1.0-r3' in info
        if package==packages[1]:assert 'install_if = alsa-ucm-gta4l=1.0-r3 pulseaudio' in info
    hashes[package.name]=hashlib.sha256(package.read_bytes()).hexdigest()
boot=json.loads((root/'artifacts/boot-current-verification.json').read_text())
assert hashlib.sha256((root/'artifacts/boot-current.img').read_bytes()).hexdigest()==boot['sha256']
hash_lines='\n'.join(f'{digest}  /tmp/gta4l-upload/{name}' for name,digest in hashes.items())
targets=' '.join('/tmp/gta4l-upload/'+package.name for package in packages)
script=f'''#!/bin/sh
set -eu
boot_hash() {{ head -c {boot['bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '{boot['sha256']}' ]
sha256sum -c - <<'HASHES'
{hash_lines}
HASHES
apk --no-network --no-interactive --no-scripts add {targets}
udevadm control --reload-rules
udevadm trigger --subsystem-match=sound --sysname-match=card0 --action=change
udevadm settle --timeout=5
udevadm info --query=property --path=/sys/class/sound/card0 | grep '^PULSE_IGNORE=1$'
[ "$(boot_hash)" = '{boot['sha256']}' ]
sha256sum /lib/firmware/postmarketos/fs1801.fsm
echo AUDIO_STARTUP_R3_INSTALLED_BOOT_UNCHANGED
'''
(root/'tools/live-install-audio-startup-r3.sh').write_text(script,newline='\n')
(root/'artifacts/audio-startup-verification.json').write_text(json.dumps({
    'date':'2026-10-12','packages_sha256':hashes,'package_contents_verified':True,
    'expected_boot_sha256':boot['sha256'],'user_confirmed_timer_mode_rough_start':True,
    'user_confirmed_interrupt_mode_smooth_start':True,'post_install_verified':False,
    'persistent_restart_verified':False,'normal_boot_verified':False},indent=2)+'\n')
print('AUDIO_STARTUP_PACKAGES_VERIFIED_AND_GUARDED_INSTALL_PREPARED')
