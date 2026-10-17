#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import dbus,os
assert os.getuid()==10000
shells=[]
for process in Path('/proc').iterdir():
    try:
        if process.name.isdigit() and process.stat().st_uid==os.getuid() and (process/'comm').read_text().strip()=='gnome-shell':shells.append(process)
    except (FileNotFoundError,ProcessLookupError):pass
assert len(shells)==1
for entry in (shells[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
        key,value=entry.decode().split('=',1);os.environ[key]=value
bus=dbus.SessionBus()
obj=bus.get_object('org.gnome.SessionManager','/org/gnome/SessionManager')
print('GNOME_SESSION_PROPERTIES',dict(dbus.Interface(obj,'org.freedesktop.DBus.Properties').GetAll('org.gnome.SessionManager')),flush=True)
PY
