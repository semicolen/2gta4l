#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import array,json,math,os,pwd,subprocess,threading,time
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
def pulse(*args):return subprocess.check_output(['pactl',*args],text=True,timeout=8,**identity)
sources=json.loads(pulse('-f','json','list','sources'))
source=next(s for s in sources if s['name'].startswith('alsa_input.') and s.get('properties',{}).get('alsa.card')=='0')
assert not source['mute'];print('DESKTOP_PHYSICAL_INPUT',source['name'],source['sample_specification'],flush=True)
process=subprocess.Popen(['parec','--raw','--format=s16le','--rate=48000','--channels=1','--device='+source['name']],stdout=subprocess.PIPE,stderr=subprocess.PIPE,**identity)
def stop():time.sleep(8);process.terminate()
def sound():
    time.sleep(2);samples=array.array('h')
    for frame in range(48000*4):
        value=int(6000*math.sin(2*math.pi*887*frame/48000)) if (frame//24000)%2==0 else 0
        samples.extend((value,value))
    played=subprocess.run(['pacat','--playback','--raw','--format=s16le','--rate=48000','--channels=2','--volume=16000'],input=samples.tobytes(),capture_output=True,timeout=8,**identity)
    print('DESKTOP_SPEAKER_PROBE',played.returncode,flush=True)
threading.Thread(target=stop,daemon=True).start();tone=threading.Thread(target=sound,daemon=True);tone.start()
data,errors=process.communicate(timeout=12);tone.join(timeout=3)
values=array.array('h',data[:len(data)//2*2]);levels=[]
for n in range(0,len(values),4800):
    window=values[n:n+4800]
    if not window:continue
    mean=sum(window)/len(window);levels.append(round(math.sqrt(sum((x-mean)**2 for x in window)/len(window)),1))
print('DESKTOP_CAPTURE_BYTES',len(data),'status',process.returncode,'diagnostics',errors.decode(errors='replace'),flush=True)
print('DESKTOP_CAPTURE_AC_RMS_100MS',levels,flush=True)
assert len(data)>48000*2*6
time.sleep(7)
for s in json.loads(pulse('-f','json','list','sources')):
    if s['name']==source['name']:print('MICROPHONE_IDLE_STATE',s['state'],flush=True)
print('CAPTURE_MIXER_IDLE',subprocess.check_output(['amixer','-c','0','cget','name=ADC1_MIXER Switch'],text=True,timeout=5),flush=True)
print('MICROPHONE_PCM_IDLE',Path('/proc/asound/card0/pcm0c/sub0/status').read_text().strip(),flush=True)
print('DESKTOP_MICROPHONE_TEST_COMPLETE',flush=True)
PY
