#!/bin/sh
set -eu
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
args = ['env', 'DISPLAY=:0', 'XAUTHORITY=/home/tablet/.Xauthority',
        'DBUS_SESSION_BUS_ADDRESS='+values['DBUS_SESSION_BUS_ADDRESS'],
        'xfce4-screensaver-command', '--lock']
subprocess.run(['su','tablet','-s','/bin/sh','-c',shlex.join(args)], check=True, timeout=10)
PY
sleep 2
ps -eo pid,args | grep -E 'screensaver|onboard' | grep -v grep
echo LOCKSCREEN_ROTATION_TEST_READY
