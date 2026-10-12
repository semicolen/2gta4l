#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
python3 -u - <<'PY'
import json,shlex,subprocess
def command(*args):return subprocess.run(args,capture_output=True,text=True,timeout=8,check=True).stdout.strip()
modules=json.loads(command('pactl','--format=json','list','modules'))
cards=[item for item in modules if item['name']=='module-alsa-card']
assert len(cards)==1 and 'device_id=bengalqrdsndcar' in cards[0]['argument']
indices=[line.split('\t')[0] for line in command('pactl','list','short','modules').splitlines() if '\tmodule-alsa-card\t' in line]
assert len(indices)==1
args=shlex.split(cards[0]['argument'].replace('namereg_fail=true','namereg_fail=false'))
command('pactl','unload-module',indices[0])
print('RESTORED_CARD_INDEX='+command('pactl','load-module','module-alsa-card',*args))
sink='alsa_output.platform-soc_qcom_msm-audio-apr_qcom_q6core-audio_sound.HiFi__Speaker__sink'
command('pactl','set-default-sink',sink)
for line in command('pactl','list','short','sink-inputs').splitlines():command('pactl','move-sink-input',line.split('\t')[0],sink)
print('RESTORED_AUDIO_SINKS='+command('pactl','list','short','sinks'))
print('INTERRUPT_AUDIO_OUTPUT_RESTORED')
PY
