#!/bin/sh
set -u
echo '=== Current sessions ==='
loginctl list-sessions
loginctl seat-status seat0
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or (p/'comm').read_text().strip()!='gnome-shell':continue
        print('SHELL',p.name,'uid',p.stat().st_uid,flush=True)
        for entry in (p/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'XDG_SESSION',b'XDG_SEAT',b'DBUS_SESSION_BUS_ADDRESS')):print(entry.decode(),flush=True)
    except (FileNotFoundError,ProcessLookupError,PermissionError):pass
paths=[Path('/home/tablet')/name for name in ('.cache/gdm/session.log','.local/share/gdm/session.log','.local/state/gdm/session.log','.xsession-errors')]
for path in paths:
    if not path.is_file():continue
    with path.open('rb') as source:
        source.seek(max(0,path.stat().st_size-250000));lines=source.read().decode(errors='replace').splitlines()
    matches=[line for line in lines if any(v in line.lower() for v in ('accelerometer','sensor','orientation','not authorized','not active','waitid(','session registration'))]
    print('LOG',path,flush=True)
    print('\n'.join(matches[-35:]),flush=True)
print('=== GDM PAM ===',flush=True)
for path in (Path('/etc/pam.d/gdm-password'),Path('/etc/pam.d/base-session'),Path('/etc/pam.d/system-login')):
    if path.exists():print(path,path.read_text(),flush=True)
PY
