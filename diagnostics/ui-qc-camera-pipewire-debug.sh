#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,pwd,subprocess
if not Path('/usr/bin/pw-dump').exists():
    args=['apk','--no-interactive','add','pipewire-tools=1.6.9-r0']
    trial=subprocess.run([args[0],'--simulate',*args[1:]],capture_output=True,text=True,timeout=25)
    print(trial.stdout,flush=True);assert trial.returncode==0,trial.stderr
    assert not any(word in trial.stdout for word in ('Upgrading','Downgrading','Purging','Removing'))
    subprocess.run(args,check=True,timeout=40)
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,XDG_RUNTIME_DIR=f'/run/user/{uid}')
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
result=subprocess.run(['pw-dump'],capture_output=True,text=True,timeout=8,**identity)
assert result.returncode==0,result.stderr
objects=json.loads(result.stdout);video=set()
for item in objects:
    info=item.get('info',{});props=info.get('props',{})
    if 'Video' in str(props.get('media.class','')) or str(props.get('node.name','')).startswith('gta4l.camera.'):
        video.add(item['id'])
        print('VIDEO_NODE',item,flush=True)
for item in objects:
    info=item.get('info',{});props=info.get('props',{})
    if int(props.get('node.id',-1)) in video or info.get('output-node-id') in video or info.get('input-node-id') in video:
        print('VIDEO_PORT_OR_LINK',item,flush=True)
for camera in ('rear','front'):print(camera,(Path('/run/gta4l-camera-pipewire-test')/(camera+'.log')).read_text()[-3000:],flush=True)
print('PIPEWIRE_VIDEO_GRAPH_CAPTURED',flush=True)
PY
