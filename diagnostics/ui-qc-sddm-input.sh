#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import pwd
import subprocess
account = pwd.getpwnam('sddm')
print('SDDM_HOME', account.pw_dir, 'UID', account.pw_uid, flush=True)
processes = [p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid == account.pw_uid
             and (p/'comm').read_text().strip() == 'kwin_wayland']
assert len(processes) == 1, len(processes)
env = dict(os.environ, HOME=account.pw_dir, USER='sddm', LOGNAME='sddm')
for entry in (processes[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=', b'DISPLAY=')):
        key, value = entry.decode().split('=', 1)
        env[key] = value
env.setdefault('XDG_RUNTIME_DIR', '/run/user/' + str(account.pw_uid))
print('SESSION_KEYS', {k: env.get(k) for k in ('DBUS_SESSION_BUS_ADDRESS','XDG_RUNTIME_DIR','WAYLAND_DISPLAY')}, flush=True)
for name in ('kcminputrc','kwinrc'):
    file = Path(account.pw_dir)/'.config'/name
    print('SAVED', name, file.read_text() if file.exists() else 'absent', flush=True)
def become_user():
    os.initgroups(account.pw_name, account.pw_gid)
    os.setgid(account.pw_gid)
    os.setuid(account.pw_uid)
code = '''
import dbus
bus = dbus.SessionBus()
props = dbus.Interface(bus.get_object('org.kde.KWin', '/org/kde/KWin/InputDevice'), 'org.freedesktop.DBus.Properties')
for name in props.Get('org.kde.KWin.InputDeviceManager','devicesSysNames'):
    device = dbus.Interface(bus.get_object('org.kde.KWin','/org/kde/KWin/InputDevice/'+str(name)), 'org.freedesktop.DBus.Properties')
    v = device.GetAll('org.kde.KWin.InputDevice')
    if v.get('touch'):
        print({k: v.get(k) for k in ('name','sysName','calibrationMatrix','orientationDBus','outputName')})
'''
subprocess.run(['python3','-c',code], env=env, preexec_fn=become_user, timeout=15, check=True)
PY
