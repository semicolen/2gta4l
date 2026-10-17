#!/bin/sh
# Read a bounded sample into RAM; retain only numeric levels, then restore.
set -eu
python3 - <<'PY'
from pathlib import Path
import array,json,math,os,re,subprocess
assert os.geteuid()==0
route_name='dmic2'
capture_seconds=4
route=[('TX DEC2 MUX','MSM_DMIC'),('TX DMIC MUX2','DMIC2' if route_name=='dmic2' else 'DMIC0'),
    ('TX_CDC_DMA_TX_3 Channels','One'),('TX_CDC_DMA_TX_3 Format','S16_LE'),
    ('TX_CDC_DMA_TX_3 SampleRate','KHZ_48'),('TX_AIF1_CAP Mixer DEC2','1'),
    ('MultiMedia1 Mixer TX_CDC_DMA_TX_3','1')]
if route_name=='qrd':
    route=[('TX DEC2 MUX','SWR_MIC'),('TX SMIC MUX2','SWR_MIC4'),
        ('ADC2 MUX','INP3'),('ADC2_MIXER Switch','1'),
        ('TX_CDC_DMA_TX_3 Channels','One'),('TX_CDC_DMA_TX_3 Format','S16_LE'),
        ('TX_CDC_DMA_TX_3 SampleRate','KHZ_48'),('TX_AIF1_CAP Mixer DEC2','1'),
        ('MultiMedia1 Mixer TX_CDC_DMA_TX_3','1')]
if route_name=='qrd-gain':
    route=[('TX DEC2 MUX','SWR_MIC'),('TX SMIC MUX2','SWR_MIC4'),
        ('ADC2 MUX','INP3'),('ADC2_MIXER Switch','1'),('ADC2 Volume','12'),
        ('TX_CDC_DMA_TX_3 Channels','One'),('TX_CDC_DMA_TX_3 Format','S16_LE'),
        ('TX_CDC_DMA_TX_3 SampleRate','KHZ_48'),('TX_AIF1_CAP Mixer DEC2','1'),
        ('Capture 0 Volume','8192'),('MultiMedia1 Mixer TX_CDC_DMA_TX_3','1')]
if route_name=='qrd-main':
    route=[('TX DEC2 MUX','SWR_MIC'),('TX SMIC MUX2','SWR_MIC0'),
        ('ADC1_MIXER Switch','1'),('ADC1 Volume','10'),
        ('TX_CDC_DMA_TX_3 Channels','One'),('TX_CDC_DMA_TX_3 Format','S16_LE'),
        ('TX_CDC_DMA_TX_3 SampleRate','KHZ_48'),('TX_AIF1_CAP Mixer DEC2','1'),
        ('Capture 0 Volume','8192'),('MultiMedia1 Mixer TX_CDC_DMA_TX_3','1')]
before=[]
for name,value in route:
    result=subprocess.run(['amixer','-c','0','cget','name='+name],capture_output=True,text=True,check=True,timeout=5)
    values=re.search(r'^\s*: values=(.+)$',result.stdout,re.M);assert values
    before.append((name,values[1]))
run=Path('/run/gta4l-microphone-test');run.mkdir(mode=0o700,exist_ok=True)
assert not run.is_symlink() and run.stat().st_uid==0
(run/'before.json').write_text(json.dumps(before)+'\n');(run/'before.json').chmod(0o600)
try:
    for name,value in route:
        subprocess.run(['amixer','-q','-c','0','cset','name='+name,value],check=True,timeout=5)
    print('STOCK_CAPTURE_ROUTE_TEST',route_name,'seconds',capture_seconds,flush=True)
    kernel_before=len(subprocess.run(['dmesg'],capture_output=True,text=True,timeout=5).stdout.splitlines())
    process=subprocess.Popen(['arecord','-D','hw:0,0','-f','S16_LE','-r','48000','-c','1',
        '--period-size=480','--buffer-size=1920','-d',str(capture_seconds),'-t','raw'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    import time,threading
    def acoustic_probe():
        import pwd
        time.sleep(2)
        shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
        uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
        env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
        env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
        wave=array.array('h')
        for frame in range(48000*4):
            value=int(6000*math.sin(2*math.pi*887*frame/48000)) if (frame//24000)%2==0 else 0
            wave.extend((value,value))
        played=subprocess.run(['pacat','--playback','--raw','--format=s16le','--rate=48000','--channels=2','--volume=16000'],
            input=wave.tobytes(),capture_output=True,timeout=9,env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
        print('QUIET_ACOUSTIC_PROBE_EXIT',played.returncode,flush=True)
    tone=threading.Thread(target=acoustic_probe,daemon=True)
    if capture_seconds>=8:tone.start()
    def inspect_active_capture():
        time.sleep(1)
        for filename in ('status','hw_params','sw_params'):
            path=Path('/proc/asound/card0/pcm0c/sub0')/filename
            if path.exists():print('ACTIVE_CAPTURE_'+filename,path.read_text(),flush=True)
    observer=threading.Thread(target=inspect_active_capture,daemon=True);observer.start()
    try:audio,errors=process.communicate(timeout=capture_seconds+6)
    except subprocess.TimeoutExpired:
        process.kill();audio,errors=process.communicate(timeout=3)
    observer.join(timeout=2)
    if tone.is_alive():tone.join(timeout=10)
    class Result:pass
    result=Result();result.returncode=process.returncode;result.stdout=audio;result.stderr=errors
    print('PCM_CAPTURE_EXIT',result.returncode,'bytes',len(result.stdout),'status',result.stderr.decode(errors='replace'),flush=True)
    if result.stdout:
        samples=array.array('h',result.stdout)
        windows=[samples[n:n+4800] for n in range(0,len(samples),4800)]
        levels=[round(math.sqrt(sum(x*x for x in window)/len(window)),1) for window in windows if window]
        means=[sum(window)/len(window) for window in windows if window]
        ac_levels=[round(math.sqrt(sum((x-mean)**2 for x in window)/len(window)),1) for window,mean in zip(windows,means)]
        print('MICROPHONE_NUMERIC_LEVELS','peak',max(map(abs,samples),default=0),
            'nonzero_samples',sum(x!=0 for x in samples),'rms_100ms',levels,'ac_rms_100ms',ac_levels,flush=True)
    messages=subprocess.run(['dmesg'],capture_output=True,text=True,timeout=5).stdout.splitlines()[kernel_before:]
    print('CAPTURE_KERNEL_MESSAGES','\n'.join(line for line in messages if any(key in line.lower() for key in ('q6','audio','asoc','afe_','pcm','snd'))) [-8000:],flush=True)
finally:
    for name,value in reversed(before):
        subprocess.run(['amixer','-q','-c','0','cset','name='+name,value],check=True,timeout=5)
    for name,value in before:
        current=subprocess.run(['amixer','-c','0','cget','name='+name],capture_output=True,text=True,check=True,timeout=5)
        assert re.search(r'^\s*: values=(.+)$',current.stdout,re.M)[1]==value
    print('ALL_TEST_CAPTURE_CONTROLS_RESTORED',flush=True)
PY
