#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
python3 -u - <<'PY'
from pathlib import Path
import array,json,math,os,subprocess,time,wave
root=Path('/home/tablet/.cache/gta4l-audio-startup')
for process in Path('/proc').iterdir():
    try:
        if process.name.isdigit() and (process/'comm').read_text().strip()=='xfce4-session':
            for item in (process/'environ').read_bytes().split(b'\0'):
                key,sep,value=item.partition(b'=')
                if sep and key.decode() in ('DBUS_SESSION_BUS_ADDRESS','DISPLAY','XAUTHORITY','XDG_RUNTIME_DIR'):
                    os.environ[key.decode()]=value.decode()
            break
    except (FileNotFoundError,PermissionError):continue
def command(*args):
    return subprocess.run(args,capture_output=True,text=True,timeout=8,check=True).stdout.strip()
assert not json.loads(command('pactl','--format=json','list','sink-inputs')),'An audio application is playing'
command('pulseaudio','--kill')
time.sleep(1)
log=root/'persistent-pulse.log'
command('pulseaudio','--start','--log-level=debug','--log-target=file:'+str(log))
time.sleep(2)
try:
    modules=json.loads(command('pactl','--format=json','list','modules'))
    cards=[item for item in modules if item['name']=='module-alsa-card']
    assert len(cards)==1 and 'device_id=bengalqrdsndcar' in cards[0]['argument'] and 'tsched=no' in cards[0]['argument']
    assert sum(item['name']=='module-udev-detect' for item in modules)==1
    assert sum(item['name']=='module-suspend-on-idle' for item in modules)==1
    print('AUTOMATIC_PERSISTENT_AUDIO_CARD='+json.dumps(cards[0],sort_keys=True))
    print('PERSISTENT_AUDIO_SINK='+command('pactl','list','sinks'))
    sinks=json.loads(command('pactl','--format=json','list','sinks'))
    assert len(sinks)==1 and sinks[0]['name']=='alsa_output.platform-soc_qcom_msm-audio-apr_qcom_q6core-audio_sound.HiFi__Speaker__sink','Expected the actual tablet speaker output'
    paths=[root/'startup-tone.wav',root/'startup-tone-44100.wav']
    data=array.array('h')
    for index in range(44100*8):
        envelope=min(1,index/441,(44100*8-1-index)/441)
        sample=int(1300*max(0,envelope)*math.sin(2*math.pi*440*index/44100))
        data.extend((sample,sample))
    with wave.open(str(paths[1]),'wb') as wav:
        wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(44100);wav.writeframes(data.tobytes())
    for trial,path in enumerate(paths,1):
        time.sleep(6)
        print('IDLE_PCM_BEFORE_TRIAL='+Path('/proc/asound/card0/pcm0p/sub0/status').read_text().strip())
        print('AUDIO_PERSISTENT_TRIAL_START='+str(trial),flush=True)
        start=time.monotonic()
        result=subprocess.run(['paplay','--latency-msec=30',str(path)],capture_output=True,text=True,timeout=13)
        elapsed=round(time.monotonic()-start,3)
        print('AUDIO_PERSISTENT_TRIAL_RESULT='+json.dumps({'trial':trial,'rate':48000 if trial==1 else 44100,'status':result.returncode,'elapsed':elapsed,'stderr':result.stderr.strip()},sort_keys=True))
        assert result.returncode==0 and 7.7<elapsed<9.2
    time.sleep(6)
    status=Path('/proc/asound/card0/pcm0p/sub0/status').read_text().strip()
    assert status=='closed'
    print('IDLE_PCM_AFTER_TEST='+status)
finally:
    command('pacmd','set-log-level','2')
    command('pacmd','set-log-target','syslog')
    print('PULSE_DEBUG_RESTORED')
lines=log.read_text(errors='replace').splitlines()
counts={key:sum(key in line for line in lines) for key in ('Underrun!','Increasing minimal latency','ALSA woke','XRUN','snd_pcm_avail')}
print('PERSISTENT_AUDIO_LOG_COUNTS='+json.dumps(counts,sort_keys=True))
assert counts['Underrun!']==0 and counts['Increasing minimal latency']==0
print('PERSISTENT_AUDIO_MODULES='+command('pactl','list','short','modules'))
print('AUDIO_PERSISTENT_TEST_END')
PY
