#!/bin/sh
set -eu
printf 'PLASMA_INPUT_INSPECTION\n'
rc-service usb-signaller status || true
ip -brief address
python3 - <<'PY'
import os
from pathlib import Path
import pwd
import subprocess

account = pwd.getpwnam('tablet')
sessions = [p for p in Path('/proc').iterdir() if p.name.isdigit()
            and p.stat().st_uid == account.pw_uid
            and (p / 'comm').read_text().strip() == 'kwin_wayland']
assert sessions, 'No running KWin Wayland process'
environment = dict(os.environ, HOME=account.pw_dir, USER=account.pw_name, LOGNAME=account.pw_name)
for item in (sessions[0] / 'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=', b'DISPLAY=')):
        key, value = item.decode().split('=', 1)
        environment[key] = value
environment['XDG_RUNTIME_DIR'] = environment.get('XDG_RUNTIME_DIR', '/run/user/10000')
sockets = sorted(Path(environment['XDG_RUNTIME_DIR']).glob('wayland-*'))
sockets = [p for p in sockets if p.is_socket()]
assert sockets, 'No Wayland display socket'
environment['WAYLAND_DISPLAY'] = sockets[0].name
environment['QT_QPA_PLATFORM'] = 'wayland'

def become_user():
    os.initgroups(account.pw_name, account.pw_gid)
    os.setgid(account.pw_gid)
    os.setuid(account.pw_uid)

script = '''
import dbus
bus = dbus.SessionBus()
manager = bus.get_object('org.kde.KWin', '/org/kde/KWin/InputDevice')
print('INPUT_MANAGER_XML')
print(dbus.Interface(manager, 'org.freedesktop.DBus.Introspectable').Introspect())
properties = dbus.Interface(manager, 'org.freedesktop.DBus.Properties')
devices = properties.GetAll('org.kde.KWin.InputDeviceManager')
print('INPUT_MANAGER_PROPERTIES', devices)
for name in devices.get('devicesSysNames', []):
    device = bus.get_object('org.kde.KWin', '/org/kde/KWin/InputDevice/' + str(name))
    values = dbus.Interface(device, 'org.freedesktop.DBus.Properties').GetAll('org.kde.KWin.InputDevice')
    if values.get('touch'):
        selected = ('name', 'sysName', 'calibrationMatrix', 'defaultCalibrationMatrix',
                    'orientationDBus', 'outputName', 'mapToWorkspace', 'inputArea', 'outputArea')
        print('TOUCH_DEVICE', name, {key: values.get(key) for key in selected})
        print(dbus.Interface(device, 'org.freedesktop.DBus.Introspectable').Introspect())
print('KWIN_SUPPORT_INFORMATION')
kwin = bus.get_object('org.kde.KWin', '/KWin')
print(dbus.Interface(kwin, 'org.kde.KWin').supportInformation())
'''
subprocess.run(['python3', '-c', script], env=environment, preexec_fn=become_user, timeout=20, check=True)
subprocess.run(['kscreen-doctor', '-o'], env=environment, preexec_fn=become_user, timeout=15, check=True)
PY
printf '\nPLASMA_INPUT_INSPECTION_END\n'
