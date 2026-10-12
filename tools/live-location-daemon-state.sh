#!/bin/sh
set -u
printf '=== Session and location process state ===\n'
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    if not p.name.isdigit(): continue
    try:
        name=(p/'comm').read_text().strip()
        if name not in ('geoclue','agent','where-am-i','xfce4-session','lightdm','ModemManager','polkitd'): continue
        status=(p/'status').read_text().splitlines()
        print(p.name,name,*(x for x in status if x.startswith(('Uid:','Gid:','Groups:'))))
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
PY
printf '=== Available logging tools ===\n'
command -v logbookctl || true
command -v logread || true
printf '=== GeoClue account and activation ===\n'
id geoclue
cat /usr/share/dbus-1/system-services/org.freedesktop.GeoClue2.service
printf 'LOCATION_DAEMON_STATE_END\n'
