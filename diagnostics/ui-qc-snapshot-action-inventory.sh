#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess,time
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}')
sockets=[p for p in Path(env['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;env['WAYLAND_DISPLAY']=sockets[0].name
identity=dict(user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid),env=env)
run=Path('/run/gta4l-snapshot-check');run.mkdir(mode=0o700,exist_ok=True)
log=open(run/'snapshot.log','ab');os.chmod(log.name,0o600)
app=subprocess.Popen(['/usr/sbin/snapshot'],stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,**identity)
log.close();time.sleep(5)
code='''import dbus,xml.etree.ElementTree as ET
bus=dbus.SessionBus()
def inspect(path,depth=0):
    if depth>3:return
    obj=bus.get_object("org.gnome.Snapshot",path)
    try:xml=dbus.Interface(obj,"org.freedesktop.DBus.Introspectable").Introspect()
    except dbus.DBusException:return
    root=ET.fromstring(xml)
    interfaces=[n.get("name") for n in root.findall("interface")]
    if "org.gtk.Actions" in interfaces:
        actions=dbus.Interface(obj,"org.gtk.Actions").List()
        print("SNAPSHOT_ACTIONS",path,list(map(str,actions)),flush=True)
    for child in root.findall("node"):inspect(path.rstrip("/")+"/"+child.get("name"),depth+1)
inspect("/org/gnome/Snapshot")
'''
probe=subprocess.run(['python3','-c',code],capture_output=True,text=True,timeout=12,**identity)
print(probe.stdout,probe.stderr,flush=True)
assert probe.returncode==0
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve().name=='snapshot':
            environ=dict(item.decode().split('=',1) for item in (p/'environ').read_bytes().split(b'\0') if b'=' in item)
            print('SNAPSHOT_RENDER_ENV',{k:environ.get(k) for k in ('GSK_RENDERER','GALLIUM_DRIVER','GTA4L_ZINK_KGSL','GST_GL_WINDOW','GST_GL_PLATFORM','GST_GL_API')},flush=True)
    except (OSError,ProcessLookupError):pass
print('SNAPSHOT_ACTION_INVENTORY_COMPLETE',flush=True)
PY
