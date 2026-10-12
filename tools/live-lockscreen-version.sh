#!/bin/sh
set -eu
apk info -v xfce4-screensaver gtk+3.0
ps -eo pid,ppid,args | grep -E 'screensaver|onboard' | grep -v grep
python3 - <<'PY'
from pathlib import Path
import subprocess
import shlex
for path in Path('/proc').iterdir():
    if not path.name.isdigit():
        continue
    try:
        if (path/'comm').read_text().strip() != 'xfce4-session':
            continue
        values = dict(e.split('=',1) for e in (path/'environ').read_bytes().decode().split('\0') if '=' in e)
        break
    except FileNotFoundError:
        continue
args = ['env', 'DBUS_SESSION_BUS_ADDRESS='+values['DBUS_SESSION_BUS_ADDRESS'],
        'gdbus', 'introspect', '--session', '--dest', 'org.xfce.ScreenSaver',
        '--object-path', '/org/xfce/ScreenSaver']
subprocess.run(['su','tablet','-s','/bin/sh','-c',shlex.join(args)], timeout=8)
PY
echo LOCKSCREEN_VERSION_END
