#!/bin/sh
set -eu
python3 - <<'PY'
import json
import os
from pathlib import Path
import dbus

assert os.getuid() == 10000
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == os.getuid() and (p / 'comm').read_text().strip() == 'kwin_wayland')
for item in (session / 'environ').read_bytes().split(b'\0'):
    if item.startswith(b'DBUS_SESSION_BUS_ADDRESS='):
        key, value = item.decode().split('=', 1)
        os.environ[key] = value
bus = dbus.SessionBus()
manager = bus.get_object('org.kde.KWin', '/org/kde/KWin/InputDevice')
names = dbus.Interface(manager, 'org.freedesktop.DBus.Properties').Get(
    'org.kde.KWin.InputDeviceManager', 'devicesSysNames')
interface = 'org.kde.KWin.InputDevice'
matrix = '-1,0,1,0,0,-1,1,0,0,0,1,0,0,0,0,1'
changed = 0
for name in names:
    obj = bus.get_object('org.kde.KWin', '/org/kde/KWin/InputDevice/' + str(name))
    properties = dbus.Interface(obj, 'org.freedesktop.DBus.Properties')
    values = properties.GetAll(interface)
    if str(values['name']) != 'himax-touchscreen' or not values['touch']:
        continue
    assert values['supportsCalibrationMatrix']
    cache = Path.home() / '.cache/gta4l-ui-qc'
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    before = cache / 'plasma-touch-before.json'
    if not before.exists():
        before.write_text(json.dumps({key: str(values[key]) for key in
                                     ('calibrationMatrix', 'orientationDBus', 'outputName')}, indent=2) + '\n')
    properties.Set(interface, 'outputName', dbus.String('DSI-1'))
    properties.Set(interface, 'calibrationMatrix', dbus.String(matrix))
    actual = str(properties.Get(interface, 'calibrationMatrix'))
    assert list(map(float, actual.split(','))) == list(map(float, matrix.split(',')))
    assert properties.Get(interface, 'outputName') == 'DSI-1'
    print('Touch matrix saved:', actual)
    print('Touch output:', properties.Get(interface, 'outputName'))
    changed += 1
assert changed == 1, changed
PY
