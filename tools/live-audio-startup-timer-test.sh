#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
python3 -u - <<'PY'
from pathlib import Path
import array,math,os,subprocess,time,wave
root=Path('/home/tablet/.cache/gta4l-audio-startup')
root.mkdir(mode=0o700,exist_ok=True)
tone=root/'startup-tone.wav'
data=array.array('h')
for index in range(48000*8):
    phase=index/48000
    envelope=min(1,index/480,((48000*8-1)-index)/480)
    sample=int(1300*max(0,envelope)*math.sin(2*math.pi*440*phase))
    data.extend((sample,sample))
with wave.open(str(tone),'wb') as wav:
    wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(48000);wav.writeframes(data.tobytes())
print('PCM_TEST_FORMAT=48000Hz stereo S16_LE, generated sine wave; no compressed decoder')
log=root/'timer-pulse.log'
def command(*args):
    return subprocess.run(args,capture_output=True,text=True,timeout=8,check=True)
command('pacmd','set-log-level','4')
command('pacmd','set-log-target','file:'+str(log))
try:
    time.sleep(6)
    for trial in range(2):
        print('AUDIO_TIMER_TRIAL_START='+str(trial+1),flush=True)
        result=subprocess.run(['paplay','--latency-msec=30',str(tone)],capture_output=True,text=True,timeout=16)
        print('AUDIO_TIMER_TRIAL_END='+str(trial+1)+' status='+str(result.returncode))
        if result.stderr:print('PLAYBACK_STDERR='+result.stderr.strip())
        if trial==0:time.sleep(6)
finally:
    command('pacmd','set-log-level','2')
    command('pacmd','set-log-target','syslog')
    print('PULSE_DEBUG_RESTORED')
lines=log.read_text(errors='replace').splitlines() if log.exists() else []
interesting=('underrun','latency','watermark','xrun','alsa woke','failed','error','suspend','sample spec','resampl','buffer','rewind')
selected=[line for line in lines if any(key in line.lower() for key in interesting)]
print('PULSE_LOG_BYTES='+str(log.stat().st_size if log.exists() else 0))
for line in selected[:220]:print('PULSE_STARTUP_LOG='+line)
print('PULSE_LOG_UNDERRUN_COUNT='+str(sum('underrun' in line.lower() for line in lines)))
print('AUDIO_TIMER_TEST_END')
PY
