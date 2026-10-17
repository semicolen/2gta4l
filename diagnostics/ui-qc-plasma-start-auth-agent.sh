#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import pwd
import subprocess
import time

account = pwd.getpwnam('tablet')
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == account.pw_uid and (p / 'comm').read_text().strip() == 'kwin_wayland')
environment = dict(os.environ, HOME=account.pw_dir, USER=account.pw_name, LOGNAME=account.pw_name,
                   XDG_RUNTIME_DIR='/run/user/10000', QT_QPA_PLATFORM='wayland',
                   QT_QUICK_BACKEND='software', LIBGL_ALWAYS_SOFTWARE='1')
for item in (session / 'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'XDG_SESSION_ID=', b'XDG_CURRENT_DESKTOP=')):
        key, value = item.decode().split('=', 1)
        environment[key] = value
sockets = sorted(p for p in Path(environment['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket())
assert sockets
environment['WAYLAND_DISPLAY'] = sockets[0].name
agent = '/usr/lib/libexec/polkit-kde-authentication-agent-1'
assert Path(agent).is_file()
existing = []
for process in Path('/proc').iterdir():
    if not process.name.isdigit() or process.stat().st_uid != account.pw_uid:
        continue
    try:
        if agent.encode() in (process / 'cmdline').read_bytes().split(b'\0'):
            existing.append(process.name)
    except FileNotFoundError:
        pass
if existing:
    print('Authentication agent already running:', existing)
else:
    directory = Path(account.pw_dir) / '.local/state/gta4l'
    directory.mkdir(parents=True, exist_ok=True)
    os.chown(directory, account.pw_uid, account.pw_gid)
    log = directory / 'plasma-polkit-agent.log'
    def become_user():
        os.initgroups(account.pw_name, account.pw_gid)
        os.setgid(account.pw_gid)
        os.setuid(account.pw_uid)
    with log.open('wb') as output:
        os.chown(log, account.pw_uid, account.pw_gid)
        os.chmod(log, 0o600)
        process = subprocess.Popen([agent], env=environment, preexec_fn=become_user,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    time.sleep(2)
    print('Authentication agent PID:', process.pid, 'exit status:', process.poll())
    print(log.read_text(errors='replace')[-6000:])
PY
