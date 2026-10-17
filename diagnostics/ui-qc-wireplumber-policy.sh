#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip() in ('wireplumber','pipewire'):
            print('POLICY_PROCESS',p.name,p.stat().st_uid,(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(),flush=True)
            print('POLICY_STDERR',(p/'fd/2').readlink(),flush=True)
    except (OSError,ProcessLookupError):pass
for base in ('/etc/wireplumber','/usr/share/wireplumber/wireplumber.conf.d','/etc/pipewire/pipewire.conf.d'):
    root=Path(base)
    for path in root.rglob('*.conf'):
        print('POLICY_CONFIG',path,'\n'+path.read_text(),flush=True)
for path in Path('/usr/share/applications').glob('*wireplumber*'):print('POLICY_DESKTOP',path,path.read_text(),flush=True)
PY
grep -A 100 '^wireplumber.profiles' /usr/share/wireplumber/wireplumber.conf | head -n 110
