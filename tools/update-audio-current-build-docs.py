"""Update current installer references only after the completed r4 checks."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
report=json.loads((root/'artifacts/current-build-verification.json').read_text())
assert report['package_revision']==4 and report['audio_release']==3
assert report['embedded_audio_startup_policy_verified']
path=root/'CURRENT-BUILD.md'
text=path.read_text()
text=text.replace('camera 1.0-r2 and GPS 1.0-r3.','camera 1.0-r2, GPS 1.0-r3 and audio 1.0-r3.')
text=text.replace('postmarketOS-SM-T505-OrangeFox-bringup-r3.zip','postmarketOS-SM-T505-OrangeFox-bringup-r4.zip')
text=text.replace('762,865,498',f"{report['bytes']:,}")
text=text.replace('410f12bb7f978ac5789a8cb446ec9de5adacd496aa7e19271be9b0c3843aad1e',report['sha256'])
text=text.replace('It includes device r22, camera r2, GPS r3, the rotation/sensor packages and',
                  'It includes device r22, camera r2, GPS r3, audio r3, the rotation/sensor packages and')
text=text.replace('Current build and installer reports are in',
    'Audio r3 fixes rough startup with interrupt scheduling on the internal card.\n'
    'Cold-start 48/44.1 kHz playback passes after an audio-server restart, and the\n'
    'user confirms smooth incoming Bluetooth audio. Normal reboot with this\n'
    'policy remains unverified; see `AUDIO-REPORT.md`.\n\nCurrent build and installer reports are in')
path.write_text(text,newline='\n')
for name in ('README.md','CAMERA-REPORT.md'):
    path=root/name
    text=path.read_text().replace('local OrangeFox r3','local OrangeFox r4')
    if name=='README.md':
        text=text.replace('ALSA and desktop audio tests with audible, clear output confirmed by the user.',
            'ALSA and desktop audio tests. Audio r3 fixes rough startup with interrupt\n'
            'scheduling; cold starts pass at 48/44.1 kHz after an audio-server restart,\n'
            'and incoming Bluetooth audio is user-confirmed smooth from the start.')
    path.write_text(text,newline='\n')
path=root/'PORT-STATUS.md'
text=path.read_text().replace('A refreshed r3 clean-install candidate now','A refreshed r4 clean-install candidate now')
text=text.replace('contains kernel #9, device r22, camera r2, GPS r3 and rotation/sensor integration.',
                  'contains kernel #9, device r22, camera r2, GPS r3, audio r3 and rotation/sensor integration.')
path.write_text(text,newline='\n')
print('CURRENT_R4_AUDIO_BUILD_DOCUMENTATION_UPDATED')
