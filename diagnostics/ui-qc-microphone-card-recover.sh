#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,pwd,subprocess,time,shlex,shutil
saved=json.loads(Path('/run/gta4l-microphone-install/pulse-before.json').read_text())
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
for args in (['alsaucm','-c','hw:0','list','_verbs'],['alsaucm','-c','hw:0','set','_verb','HiFi']):
    p=subprocess.run(args,capture_output=True,text=True,timeout=12);print('UCM_CHECK',args[-2:],p.returncode,p.stdout,p.stderr,flush=True)
def pulse(*args):
    p=subprocess.run(['pactl',*args],capture_output=True,text=True,timeout=12,**identity)
    print('PULSE_CHECK',args[0],p.returncode,p.stdout,p.stderr,flush=True);return p
log=Path(env['XDG_RUNTIME_DIR'])/'gta4l-pulse-mic-check.log'
def debug(*args):
    if shutil.which('pacmd'):
        p=subprocess.run(['pacmd',*args],capture_output=True,text=True,timeout=5,**identity)
        print('PULSE_DEBUG_CONTROL',args[0],p.returncode,p.stdout,p.stderr,flush=True)
debug('set-log-target','file:'+str(log));debug('set-log-level','4')
try:pulse('load-module',saved['module']['name'],*shlex.split(saved['module']['argument']),'rate=48000')
finally:debug('set-log-level','2');debug('set-log-target','auto')
time.sleep(1)
if log.exists():print('MICROPHONE_CARD_DIAGNOSTICS',log.read_text(errors='replace')[-17000:],flush=True)
pulse('list','short','cards');pulse('list','short','sinks');pulse('list','short','sources')
messages=subprocess.check_output(['dmesg'],text=True,timeout=5).splitlines()
print('AUDIO_KERNEL_ERRORS','\n'.join(line for line in messages[-900:] if any(s in line.lower() for s in ('q6','audio','asoc','hw_params','snd','afe_','fsm','pcm'))) [-9000:],flush=True)
PY
