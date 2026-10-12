#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
python3 -u - <<'PY'
from pathlib import Path
import json,subprocess
def objects(kind):
    result=subprocess.run(['pactl','--format=json','list',kind],capture_output=True,text=True,timeout=8,check=True)
    return json.loads(result.stdout)
modules=objects('modules');sources=objects('sources');sinks=objects('sinks')
bt=[item for item in sources if item['name'].startswith('bluez_source.')]
speaker=[item for item in sinks if item['name']=='alsa_output.platform-soc_qcom_msm-audio-apr_qcom_q6core-audio_sound.HiFi__Speaker__sink']
assert len(speaker)==1
data={
    'bluetooth_source_count':len(bt),
    'bluetooth_sources':[{'state':item['state'],'sample_specification':item.get('sample_specification')} for item in bt],
    'loopback_module_count':sum(item['name']=='module-loopback' for item in modules),
    'internal_card_count':sum(item['name']=='module-alsa-card' for item in modules),
    'speaker_state':speaker[0]['state'],
    'speaker_access_mode':speaker[0]['properties'].get('device.access_mode'),
    'speaker_buffer_bytes':speaker[0]['properties'].get('device.buffering.buffer_size'),
    'speaker_period_bytes':speaker[0]['properties'].get('device.buffering.fragment_size'),
    'pcm_status':Path('/proc/asound/card0/pcm0p/sub0/status').read_text().strip()}
print('BLUETOOTH_RECEIVE_AUDIO_STATE='+json.dumps(data,sort_keys=True))
print('AUDIO_BLUETOOTH_RECEIVE_STATE_END')
PY
