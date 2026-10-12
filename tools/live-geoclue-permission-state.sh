#!/bin/sh
set -eu
printf '=== Agent diagnostics ===\n'
cat /home/tablet/.cache/gta4l-gps/agent.log
printf '=== Location process owners ===\n'
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    if not p.name.isdigit(): continue
    try:
        exe=str((p/'exe').resolve())
        if exe in ('/usr/libexec/geoclue','/usr/libexec/geoclue-2.0/demos/agent','/usr/libexec/geoclue-2.0/demos/where-am-i'):
            status=(p/'status').read_text()
            uid=next(x for x in status.splitlines() if x.startswith('Uid:'))
            print(p.name,exe,uid)
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
PY
printf '=== Config overrides ===\n'
ls /etc/geoclue/conf.d
printf 'GEOCLUE_PERMISSION_STATE_END\n'
