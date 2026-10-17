#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
code='''import dbus,os
from pathlib import Path
bus=dbus.SessionBus()
address=dbus.Interface(bus.get_object('org.a11y.Bus','/org/a11y/bus'),'org.a11y.Bus').GetAddress()
a11y=dbus.bus.BusConnection(str(address))
daemon=dbus.Interface(a11y.get_object('org.freedesktop.DBus','/org/freedesktop/DBus'),'org.freedesktop.DBus')
visited=set();count=0
def walk(name,path,depth=0):
    global count
    if depth>14 or count>220 or (name,path) in visited:return
    visited.add((name,path));count+=1
    obj=a11y.get_object(name,path);acc=dbus.Interface(obj,'org.a11y.atspi.Accessible')
    interfaces=list(map(str,acc.GetInterfaces()))
    if 'org.a11y.atspi.Action' in interfaces:
        action=dbus.Interface(obj,'org.a11y.atspi.Action')
        props=dbus.Interface(obj,'org.freedesktop.DBus.Properties')
        print('CAMERA_ACCESSIBLE_ACTION',str(name),str(path),'role',str(acc.GetRoleName()),'name',str(props.Get('org.a11y.atspi.Accessible','Name')),'actions',list(action.GetActions()),flush=True)
    for child in acc.GetChildren():
        if str(child[0]):walk(str(child[0]),str(child[1]),depth+1)
root=a11y.get_object('org.a11y.atspi.Registry','/org/a11y/atspi/accessible/root')
for child in dbus.Interface(root,'org.a11y.atspi.Accessible').GetChildren():
    try:
        pid=int(daemon.GetConnectionUnixProcessID(child[0]))
        if (Path('/proc')/str(pid)/'exe').resolve().name=='snapshot':walk(str(child[0]),str(child[1]))
    except (dbus.DBusException,OSError):continue
print('SNAPSHOT_ACCESSIBLE_NODES',count)
'''
result=subprocess.run(['python3','-c',code],env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),capture_output=True,text=True,timeout=25)
print(result.stdout,result.stderr,flush=True);assert result.returncode==0
log=Path('/run/gta4l-snapshot-check/snapshot.log')
if log.exists():print('SNAPSHOT_RECENT_DIAGNOSTICS',log.read_text(errors='replace')[-10000:])
PY
