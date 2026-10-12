#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
python3 -u - <<'PY'
from pathlib import Path
import json,shlex,subprocess,time
root=Path('/home/tablet/.cache/gta4l-audio-startup')
def command(*args,timeout=8):
    return subprocess.run(args,capture_output=True,text=True,timeout=timeout,check=True).stdout.strip()
modules=json.loads(command('pactl','--format=json','list','modules'))
cards=[item for item in modules if item['name']=='module-alsa-card' and 'device_id="0"' in item['argument']]
assert len(cards)==1,'Expected one automatically discovered internal card'
assert not json.loads(command('pactl','--format=json','list','sink-inputs')),'An audio application is still playing'
original=cards[0]
indices=[line.split('\t')[0] for line in command('pactl','list','short','modules').splitlines() if '\tmodule-alsa-card\t' in line]
assert len(indices)==1,'Expected one internal ALSA module index'
(root/'original-card.json').write_text(json.dumps(original,indent=2)+'\n')
arguments=shlex.split(original['argument'])
arguments=[arg for arg in arguments if not arg.startswith(('tsched=','fragments=','fragment_size='))]
arguments+=['tsched=no','fragments=4','fragment_size=1920']
command('pactl','unload-module',indices[0])
try:
    new_index=command('pactl','load-module','module-alsa-card',*arguments)
except Exception:
    command('pactl','load-module','module-alsa-card',*shlex.split(original['argument']))
    print('ORIGINAL_AUDIO_CARD_RESTORED')
    raise
print('INTERRUPT_CARD_INDEX='+new_index)
print('INTERRUPT_SINK_STATE='+command('pactl','list','sinks'))
log=root/'interrupt-pulse.log'
command('pacmd','set-log-level','4')
command('pacmd','set-log-target','file:'+str(log))
results=[]
try:
    time.sleep(6)
    for trial in range(2):
        print('AUDIO_INTERRUPT_TRIAL_START='+str(trial+1),flush=True)
        start=time.monotonic()
        try:
            played=subprocess.run(['paplay','--latency-msec=30',str(root/'startup-tone.wav')],capture_output=True,text=True,timeout=13)
            result={'trial':trial+1,'status':played.returncode,'elapsed':round(time.monotonic()-start,3),'stderr':played.stderr.strip()}
        except subprocess.TimeoutExpired:
            result={'trial':trial+1,'status':124,'elapsed':round(time.monotonic()-start,3)}
        results.append(result)
        print('AUDIO_INTERRUPT_TRIAL_RESULT='+json.dumps(result,sort_keys=True))
        if trial==0:time.sleep(6)
finally:
    command('pacmd','set-log-level','2')
    command('pacmd','set-log-target','syslog')
    print('PULSE_DEBUG_RESTORED')
lines=log.read_text(errors='replace').splitlines() if log.exists() else []
counts={key:sum(key in line for line in lines) for key in ('Underrun!','Increasing minimal latency','ALSA woke','snd_pcm_avail','XRUN')}
print('INTERRUPT_LOG_COUNTS='+json.dumps(counts,sort_keys=True))
for line in [line for line in lines if any(key in line.lower() for key in ('underrun','latency','failed','error','buffer'))][:90]:print('INTERRUPT_LOG='+line)
if not all(item['status']==0 and 7.7<item['elapsed']<9.2 for item in results):
    command('pactl','unload-module',new_index)
    command('pactl','load-module','module-alsa-card',*shlex.split(original['argument']))
    print('ORIGINAL_AUDIO_CARD_RESTORED')
    raise SystemExit('Interrupt playback did not pass duration/status checks')
print('AUDIO_INTERRUPT_TEST_END')
PY
