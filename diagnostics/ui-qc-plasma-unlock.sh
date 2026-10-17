#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import subprocess

session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == 10000 and (p / 'comm').read_text().strip() == 'kwin_wayland')
environment = dict(item.decode().split('=', 1) for item in (session / 'environ').read_bytes().split(b'\0')
                   if b'=' in item)
session_id = environment['XDG_SESSION_ID']
owner = subprocess.check_output(['loginctl', 'show-session', session_id, '-p', 'User', '--value'], text=True).strip()
assert owner == '10000'
subprocess.run(['loginctl', 'unlock-session', session_id], check=True, timeout=10)
print('Unlocked current tablet graphical test session:', session_id)
PY
