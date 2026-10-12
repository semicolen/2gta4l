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
        values = dict(entry.split('=', 1) for entry in (path/'environ').read_bytes().decode().split('\0') if '=' in entry)
        break
    except FileNotFoundError:
        continue
for channel in ['xfce4-desktop', 'xfce4-panel', 'xfce4-screensaver']:
    print('CHANNEL', channel, flush=True)
    argv = ['env', 'DISPLAY=:0', 'XAUTHORITY=/home/tablet/.Xauthority',
            'DBUS_SESSION_BUS_ADDRESS='+values['DBUS_SESSION_BUS_ADDRESS'],
            'xfconf-query', '-c', channel, '-lv']
    subprocess.run(['su','tablet','-s','/bin/sh','-c',shlex.join(argv)], timeout=8)
PY
echo XFCE_ROTATION_CONFIG_END
