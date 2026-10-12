#!/usr/bin/env python3
"""Validate the locally built speaker configuration and prepare its update."""
from pathlib import Path
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
package = root / 'artifacts/apks/alsa-ucm-gta4l-1.0-r1.apk'
with tarfile.open(package, 'r:gz', ignore_zeros=True) as archive:
    members = {m.name.lstrip('./'): m for m in archive}
    prefix = 'usr/share/alsa/ucm2/'
    for name in ['gta4l.conf', 'HiFi.conf']:
        assert archive.extractfile(members[prefix + 'Qualcomm/gta4l/' + name]).read() == (
            root / 'port/alsa-ucm-gta4l' / name).read_bytes()
    link = members[prefix + 'conf.d/bengal-qrd-snd-/bengal-qrd-snd-card.conf']
    assert link.issym() and link.linkname == '../../Qualcomm/gta4l/gta4l.conf'
    for member in members.values():
        assert '..' not in Path(member.name).parts and not member.name.startswith('/')
digest = hashlib.sha256(package.read_bytes()).hexdigest()
boot = json.loads((root / 'artifacts/plane-resume-fix-verification.json').read_text())
script = f'''#!/bin/sh
set -eu
boot_hash() {{ head -c {boot['boot_bytes']} /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '{boot['boot_sha256']}' ]
sha256sum -c - <<'HASHES'
{digest}  /tmp/gta4l-upload/{package.name}
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/{package.name}
alsaucm -c hw:0 list _verbs
alsaucm -c hw:0 set _verb HiFi list _devices set _enadev Speaker get PlaybackPCM/Speaker
[ "$(boot_hash)" = '{boot['boot_sha256']}' ]
echo AUDIO_UCM_INSTALLED_BOOT_UNCHANGED
'''
(root / 'tools/live-install-audio-ucm.sh').write_text(script, newline='\n')
(root / 'artifacts/audio-ucm-verification.json').write_text(json.dumps({
    'package': package.name, 'package_sha256': digest,
    'packaged_configuration_verified': True,
    'boot_sha256': boot['boot_sha256'],
    'runtime_ucm_verified': False, 'desktop_playback_verified': False,
    'microphone_verified': False, 'headset_verified': False,
}, indent=2) + '\n')
print('Validated packaged routing files and card alias; prepared guarded update')
