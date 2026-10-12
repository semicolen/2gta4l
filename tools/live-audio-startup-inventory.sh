#!/bin/sh
set -eu
python3 -u - <<'PY'
from pathlib import Path
import json,subprocess
print('BOOT_ID='+Path('/proc/sys/kernel/random/boot_id').read_text().strip())
def run(args,label):
    result=subprocess.run(args,capture_output=True,text=True,timeout=8)
    print(label+'='+result.stdout.strip())
    if result.returncode:print(label+'_ERROR='+result.stderr.strip())
for args,label in [(['apk','info','-v','alsa-ucm-gta4l','pulseaudio','pulseaudio-alsa','alsa-lib'],'AUDIO_PACKAGES'),
                   (['cat','/proc/asound/cards'],'ALSA_CARDS')]:run(args,label)
for args,label in [(['pactl','info'],'PULSE_INFO'),(['pactl','list','sinks'],'PULSE_SINKS'),
                   (['pactl','list','short','sink-inputs'],'PULSE_INPUTS'),(['pactl','list','short','modules'],'PULSE_MODULES')]:
    run(['su','tablet','-s','/bin/sh','-c','XDG_RUNTIME_DIR=/run/user/10000 '+' '.join(args)],label)
for root in (Path('/etc/pulse'),Path('/home/tablet/.config/pulse')):
    for name in ('daemon.conf','default.pa'):
        path=root/name
        if path.exists():
            lines=[line.strip() for line in path.read_text().splitlines() if line.strip() and not line.lstrip().startswith(('#',';'))]
            print('PULSE_CONFIG='+json.dumps({'path':str(path),'active':lines}))
for path in sorted(Path('/proc/asound').glob('card*/pcm*p/sub*/status')):
    print('PCM_STATUS='+json.dumps({'path':str(path),'text':path.read_text()}))
kernel=subprocess.run(['dmesg'],capture_output=True,text=True,timeout=8).stdout.splitlines()
need=('fsm','q6asm','q6afe','bengal media','alsa','audio','mi2s')
for line in [line for line in kernel if 'Kernel command line:' not in line and any(key in line.lower() for key in need)][-100:]:
    print('AUDIO_KERNEL='+line)
print('AUDIO_STARTUP_INVENTORY_END')
PY
