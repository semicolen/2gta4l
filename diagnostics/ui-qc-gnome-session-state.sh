#!/bin/sh
# Read the logged-in GNOME session's native monitor and input settings.
set -eu
python3 - <<'PY'
import os, subprocess
from pathlib import Path
import dbus
from gi.repository import Gio
assert os.getuid()==10000
sessions=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='gnome-shell': sessions.append(p)
    except (FileNotFoundError,ProcessLookupError): pass
assert len(sessions)==1,'Expected one logged-in GNOME compositor'
print('GNOME_COMPOSITOR_PID',sessions[0].name,flush=True)
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1);os.environ[key]=value
    if entry.startswith((b'LIBGL_',b'GALLIUM_',b'MESA_',b'GTA4L_',b'VK_DRIVER_')):
        print(entry.decode(),flush=True)
bus=dbus.SessionBus()
obj=bus.get_object('org.gnome.Mutter.DisplayConfig','/org/gnome/Mutter/DisplayConfig')
serial,monitors,logical,properties=dbus.Interface(obj,'org.gnome.Mutter.DisplayConfig').GetCurrentState()
print('DISPLAY_INTERFACE_PROPERTIES',dict(dbus.Interface(obj,'org.freedesktop.DBus.Properties').GetAll('org.gnome.Mutter.DisplayConfig')),flush=True)
for spec,modes,props in monitors:
    print('MONITOR',tuple(spec),'CURRENT_MODE',[(str(m[0]),int(m[1]),int(m[2]),float(m[3])) for m in modes if m[6].get('is-current')],flush=True)
for x,y,scale,transform,primary,outputs,props in logical:
    print('LOGICAL_MONITOR','xy',int(x),int(y),'scale',float(scale),'transform',int(transform),'primary',bool(primary),'outputs',[tuple(v) for v in outputs],flush=True)
print('DISPLAY_PROPERTIES',dict(properties),flush=True)
source=Gio.SettingsSchemaSource.get_default()
for schema_id,keys in (
    ('org.gnome.desktop.a11y.applications',('screen-keyboard-enabled',)),
    ('org.gnome.desktop.interface',('scaling-factor','text-scaling-factor')),
    ('org.gnome.settings-daemon.peripherals.touchscreen',('orientation-lock',)),
):
    schema=source.lookup(schema_id,True)
    if schema and schema.get_path():
        settings=Gio.Settings.new(schema_id)
        for key in keys:
            if schema.has_key(key):print('SETTING',schema_id,key,settings.get_value(key).print_(True),flush=True)
try:
    obj=dbus.SystemBus().get_object('net.hadess.SensorProxy','/net/hadess/SensorProxy')
    print('SENSOR',dict(dbus.Interface(obj,'org.freedesktop.DBus.Properties').GetAll('net.hadess.SensorProxy')),flush=True)
except dbus.DBusException as error:print('SENSOR_QUERY',error.get_dbus_name(),flush=True)
subprocess.run(['gnome-shell','--version'],check=True,timeout=10)
print('GNOME_SESSION_STATE_COMPLETE',flush=True)
PY
