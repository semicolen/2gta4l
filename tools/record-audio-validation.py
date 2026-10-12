#!/usr/bin/env python3
"""Record measured speaker results without overstating full audio support."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
required = {
    'device-r13-speaker-silence-test.raw': 'SILENCE_PLAYBACK_STATUS=0',
    'device-r13-audio-ucm-r1-install.raw': 'AUDIO_UCM_INSTALLED_BOOT_UNCHANGED',
    'device-r13-audio-desktop-profile-r1.raw': 'DESKTOP_SPEAKER_PROFILE_READY',
    'device-r13-desktop-speaker-result.raw': 'DESKTOP_PLAYBACK_STATUS=0',
    'device-r14-audio-package-install.raw': 'DEVICE_R14_INSTALLED_BOOT_UNCHANGED',
    'device-r14-audio-normal-boot-state.raw': 'AUDIO_NORMAL_BOOT_STATE_END',
    'device-r14-speaker-after-reboot-start.raw': 'SINGLE_AUTOMATIC_AUDIO_CARD_VERIFIED',
    'device-r14-speaker-after-reboot-result.raw': 'AUTOMATIC_DESKTOP_PLAYBACK_STATUS=0',
}
for name, marker in required.items():
    assert marker in (evidence / name).read_text(), name
path = root / 'artifacts/audio-ucm-verification.json'
report = json.loads(path.read_text())
report.update(desktop_playback_verified=True,
              user_confirmed_alsa_tone=True,
              user_confirmed_desktop_tone_clear=True,
              automatic_desktop_audio_after_reboot_verified=True,
              user_confirmed_volume_keys=True,
              normal_reboot_tests=1,
              sustained_streaming_verified=False,
              microphone_verified=False, headset_verified=False,
              suspend_verified=False,
              evidence_sha256={name: hashlib.sha256((evidence / name).read_bytes()).hexdigest()
                               for name in required})
path.write_text(json.dumps(report, indent=2) + '\n')
sums = root / 'artifacts/SHA256SUMS'
lines = [line for line in sums.read_text().splitlines()
         if line and '  apks/' not in line]
for package in sorted((root / 'artifacts/apks').glob('*.apk')):
    lines.append(hashlib.sha256(package.read_bytes()).hexdigest()+'  apks/'+package.name)
sums.write_text('\n'.join(lines)+'\n')
print('Recorded staged speaker tests, preserved boot, package hashes, and remaining validation boundary')
