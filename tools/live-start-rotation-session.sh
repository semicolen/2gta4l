#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import subprocess
import shlex
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and (p/'comm').read_text().strip() == 'xfce4-session')
values = dict(entry.split('=', 1) for entry in (session/'environ').read_bytes().decode().split('\0')
              if '=' in entry)
assert values['DISPLAY'] == ':0'
argv = ['env', 'DISPLAY=:0', 'XAUTHORITY=/home/tablet/.Xauthority',
        'DBUS_SESSION_BUS_ADDRESS='+values['DBUS_SESSION_BUS_ADDRESS'],
        'gdbus', 'call', '--session', '--dest', 'org.postmarketos.Gta4l.Rotation',
        '--object-path', '/org/postmarketos/Gta4l/Rotation',
        '--method', 'org.freedesktop.DBus.Peer.Ping']
subprocess.run(['su', 'tablet', '-s', '/bin/sh', '-c', shlex.join(argv)], check=True, timeout=20)
PY
sleep 3
cat /home/tablet/.cache/gta4l-rotation/status.json
tail -n 12 /home/tablet/.cache/gta4l-rotation/rotation.log
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
xrandr --current | head -n 4
xinput --list --short | grep himax
echo ROTATION_SESSION_START_END
