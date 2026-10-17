#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import time
import dbus
assert os.getuid()==10000
processes=[p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid()
           and (p/'comm').read_text().strip()=='kwin_wayland']
assert len(processes)==1
for entry in (processes[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=')):
        key,value=entry.decode().split('=',1)
        os.environ[key]=value
backup=Path.home()/'.cache/gta4l-ui-qc/kwinrc-before-tablet-mode'
backup.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
config=Path.home()/'.config/kwinrc'
if config.exists() and not backup.exists():
    backup.write_bytes(config.read_bytes())
    backup.chmod(0o600)
bus=dbus.SessionBus()
properties=dbus.Interface(bus.get_object('org.kde.KWin','/org/kde/KWin'),'org.freedesktop.DBus.Properties')
def set_mode(setting, wanted):
    subprocess.run(['kwriteconfig6','--file','kwinrc','--group','Input','--key','TabletMode',setting,'--notify'],check=True,timeout=10)
    deadline=time.monotonic()+8
    while time.monotonic()<deadline:
        if bool(properties.Get('org.kde.KWin.TabletModeManager','tabletMode'))==wanted:
            print('Observed tablet mode:', wanted, flush=True)
            return
        time.sleep(0.25)
    raise RuntimeError('KWin did not apply tablet-mode change')
# Wait for both transitions so a busy compositor cannot coalesce the signals.
set_mode('off',False)
time.sleep(1)
set_mode('on',True)
dbus.Interface(bus.get_object('org.kde.KWin','/KWin'),'org.kde.KWin').reconfigure()
time.sleep(3)
mode=properties.GetAll('org.kde.KWin.TabletModeManager')
print('TABLET_MODE',dict(mode),flush=True)
assert mode['tabletMode']
sensor=dbus.SystemBus().get_object('net.hadess.SensorProxy','/net/hadess/SensorProxy')
print('SENSOR',dict(dbus.Interface(sensor,'org.freedesktop.DBus.Properties').GetAll('net.hadess.SensorProxy')),flush=True)
print('Saved native Plasma tablet-mode setting',flush=True)
PY
