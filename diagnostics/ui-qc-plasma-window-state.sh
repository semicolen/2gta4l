#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import dbus

uid = os.getuid()
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == uid and (p / 'comm').read_text().strip() == 'kwin_wayland')
for item in (session / 'environ').read_bytes().split(b'\0'):
    if item.startswith(b'DBUS_SESSION_BUS_ADDRESS='):
        key, value = item.decode().split('=', 1)
        os.environ[key] = value
bus = dbus.SessionBus()
tablet = bus.get_object('org.kde.KWin', '/org/kde/KWin')
print('TABLET_MODE:', dbus.Interface(tablet, 'org.freedesktop.DBus.Properties').GetAll('org.kde.KWin.TabletModeManager'))
keyboard = bus.get_object('org.kde.KWin', '/VirtualKeyboard')
print('VIRTUAL_KEYBOARD:', dbus.Interface(keyboard, 'org.freedesktop.DBus.Properties').GetAll('org.kde.kwin.VirtualKeyboard'))
try:
    screen = bus.get_object('org.freedesktop.ScreenSaver', '/ScreenSaver')
    print('SCREEN_LOCK_ACTIVE:', dbus.Interface(screen, 'org.freedesktop.ScreenSaver').GetActive())
except dbus.DBusException as error:
    print('Screen lock query:', error.get_dbus_name())
obj = bus.get_object('org.kde.KWin', '/Scripting')
print(dbus.Interface(obj, 'org.freedesktop.DBus.Introspectable').Introspect())
PY
