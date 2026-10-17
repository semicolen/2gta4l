#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import pwd
import signal
import subprocess

account = pwd.getpwnam('tablet')
for process in Path('/proc').iterdir():
    if not process.name.isdigit() or process.stat().st_uid != account.pw_uid:
        continue
    try:
        if b'/tmp/gta4l-upload/ui-qc-touch-targets.py' in (process / 'cmdline').read_bytes().split(b'\0'):
            os.kill(int(process.name), signal.SIGTERM)
    except (FileNotFoundError, ProcessLookupError):
        pass
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == account.pw_uid
               and (p / 'comm').read_text().strip() == 'kwin_wayland')
environment = dict(os.environ, HOME=account.pw_dir, USER=account.pw_name, LOGNAME=account.pw_name,
                   XDG_RUNTIME_DIR='/run/user/10000', GDK_BACKEND='wayland')
for item in (session / 'environ').read_bytes().split(b'\0'):
    if item.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=')):
        key, value = item.decode().split('=', 1)
        environment[key] = value
sockets = sorted(p for p in Path(environment['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket())
assert sockets
environment['WAYLAND_DISPLAY'] = sockets[0].name

def become_user():
    os.initgroups(account.pw_name, account.pw_gid)
    os.setgid(account.pw_gid)
    os.setuid(account.pw_uid)

with open('/tmp/gta4l-touch-targets.log', 'wb') as log:
    process = subprocess.Popen(['python3', '/tmp/gta4l-upload/ui-qc-touch-targets.py'],
                               env=environment, preexec_fn=become_user,
                               stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
print('Touch alignment check launched:', process.pid)
PY
