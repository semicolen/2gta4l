#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,pwd,subprocess
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,XDG_RUNTIME_DIR=f'/run/user/{uid}')
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip()=='wireplumber':
            processenv=dict(item.decode().split('=',1) for item in (p/'environ').read_bytes().split(b'\0') if b'=' in item)
            print('WP_CONNECTION_ENV',{k:v for k,v in processenv.items() if k.startswith(('PIPEWIRE','WIREPLUMBER','XDG_RUNTIME'))},flush=True)
    except (OSError,ProcessLookupError):pass
result=subprocess.run(['pw-dump'],capture_output=True,text=True,timeout=8,**identity)
for item in json.loads(result.stdout):
    props=item.get('info',{}).get('props',{})
    if 'wireplumber' in str(props.get('application.name','')).lower() or 'Metadata' in item.get('type',''):
        print('WP_CONNECTION_OBJECT',item,flush=True)
for command in (['wpctl','status'],['wpctl','settings']):
    try:
        result=subprocess.run(command,capture_output=True,text=True,timeout=8,**identity)
        print('WPCTL',command,result.returncode,result.stdout[-6000:],result.stderr,flush=True)
    except FileNotFoundError:print('WPCTL_NOT_INSTALLED',flush=True)
PY
