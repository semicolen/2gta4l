#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,pwd,socket,subprocess,time
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
code='''import dbus
bus=dbus.SessionBus()
if bus.name_has_owner('org.gnome.Snapshot'):
    dbus.Interface(bus.get_object('org.gnome.Snapshot','/org/gnome/Snapshot'),'org.gtk.Actions').Activate('quit',[],{})
print('NATIVE_CAMERA_NORMAL_QUIT_REQUESTED',flush=True)
'''
p=subprocess.run(['python3','-c',code],capture_output=True,text=True,timeout=10,env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
print(p.stdout,p.stderr,flush=True);assert p.returncode==0
time.sleep(8)
running=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve().name=='snapshot':running.append(int(p.name))
    except (OSError,ProcessLookupError):pass
assert not running,'Camera application remains active'
status=None
for attempt in range(5):
    connection=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);connection.settimeout(2)
    try:
        connection.connect('/run/gta4l-camera/control.sock');connection.sendall(b'status\n')
        data=b''
        while b'\n' not in data and len(data)<4096:data+=connection.recv(4096)
        status=json.loads(data);break
    except (OSError,ValueError):time.sleep(1)
    finally:connection.close()
assert status is not None
print('CAMERA_BROKER_IDLE_RUNNING',status.get('running'),flush=True)
print('CAMERA_TEMPORARY_FRAME_COUNT',len(list(Path('/run/gta4l-camera/frames').glob('*.ppm'))),flush=True)
assert status.get('running') is False
assert not list(Path('/run/gta4l-camera/frames').glob('*.ppm'))
print('SIGNED_CAMERA_NORMAL_CLOSE_AND_HARDWARE_IDLE_PASSED',flush=True)
PY
