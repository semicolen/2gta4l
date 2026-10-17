#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,XDG_RUNTIME_DIR=f'/run/user/{uid}')
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
for args in (['pactl','list','short','sources'],['pactl','list','short','source-outputs'],['pactl','list','cards']):
    result=subprocess.run(args,capture_output=True,text=True,timeout=8,**identity)
    print('AUDIO_SERVER',args,result.returncode,result.stdout[-12000:],result.stderr,flush=True)
for args in (['arecord','-l'],['amixer','-c','0','contents']):
    result=subprocess.run(args,capture_output=True,text=True,timeout=10)
    print('ALSA',args,result.returncode,result.stdout,result.stderr,flush=True)
print('CORE_PATTERN',Path('/proc/sys/kernel/core_pattern').read_text(),flush=True)
for path in (Path('/run/gta4l-camera-pipewire-test/snapshot.log'),Path(user.pw_dir)/'.cache/gdm/session.log'):
    if not path.exists():continue
    with path.open('rb') as stream:
        stream.seek(max(0,path.stat().st_size-256*1024))
        lines=stream.read().decode(errors='replace').splitlines()
    if path.name=='snapshot.log':selected=lines[-60:]
    else:selected=[s for s in lines if any(x in s.lower() for x in ('snapshot','segmentation','assertion','gtk4paintable','gstreamer','sigbus'))][-40:]
    print('CAMERA_CRASH_LOG',path,'\n'+'\n'.join(selected),flush=True)
kernel=subprocess.run(['dmesg'],capture_output=True,text=True,timeout=8).stdout.splitlines()
print('CAMERA_KERNEL_ERRORS','\n'.join(s for s in kernel if any(x in s.lower() for x in ('snapshot','segfault','out of memory','gpu fault','gpu pagefault')))[-5000:],flush=True)
PY
cat /proc/asound/pcm
