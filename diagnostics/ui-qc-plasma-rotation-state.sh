#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
import dbus
assert os.getuid() == 10000
processes = [p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid == os.getuid()
             and (p/'comm').read_text().strip() == 'kwin_wayland']
assert len(processes) == 1, 'Expected one logged-in desktop compositor'
for entry in (processes[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=')):
        key, value = entry.decode().split('=', 1)
        os.environ[key] = value
sockets = [p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets) == 1, 'Expected one user display socket'
os.environ['WAYLAND_DISPLAY'] = sockets[0].name
os.environ['QT_QPA_PLATFORM'] = 'wayland'
bus = dbus.SessionBus()
obj = bus.get_object('org.kde.KWin','/org/kde/KWin')
print('TABLET_MODE', dict(dbus.Interface(obj,'org.freedesktop.DBus.Properties').GetAll('org.kde.KWin.TabletModeManager')), flush=True)
sensor = dbus.SystemBus().get_object('net.hadess.SensorProxy','/net/hadess/SensorProxy')
print('SENSOR', dict(dbus.Interface(sensor,'org.freedesktop.DBus.Properties').GetAll('net.hadess.SensorProxy')), flush=True)
subprocess.run(['kscreen-doctor','-o'], timeout=10, check=True)
file = Path.home()/'.config/kwinrc'
print('KWIN_SETTINGS', file.read_text() if file.exists() else 'absent', flush=True)
PY
