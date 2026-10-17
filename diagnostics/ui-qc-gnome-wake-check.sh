#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import dbus,os,time
assert os.getuid()==10000
shells=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='gnome-shell':shells.append(p)
    except (FileNotFoundError,ProcessLookupError):pass
assert len(shells)==1
for entry in (shells[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=entry.decode().split('=',1);os.environ[key]=value
props=dbus.Interface(dbus.SessionBus().get_object('org.gnome.Mutter.DisplayConfig','/org/gnome/Mutter/DisplayConfig'),'org.freedesktop.DBus.Properties')
interface='org.gnome.Mutter.DisplayConfig'
before=int(props.Get(interface,'PowerSaveMode'))
assert before==0,('Display must start active',before)
print('GNOME_COMPOSITOR_PID',shells[0].name,'POWER_BEFORE',before,flush=True)
try:
    props.Set(interface,'PowerSaveMode',dbus.Int32(3))
    print('POWER_OFF_REQUESTED',flush=True)
    time.sleep(5)
finally:
    props.Set(interface,'PowerSaveMode',dbus.Int32(0))
    print('POWER_ON_REQUESTED',flush=True)
time.sleep(2)
assert int(props.Get(interface,'PowerSaveMode'))==0
assert shells[0].exists()
print('GNOME_DPMS_OFF_ON_API_PASS; physical display confirmation pending',flush=True)
PY
