#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
for root in ('/home/quickUser/.cache/gdm','/var/log'):
    for path in Path(root).glob('session.log' if root.startswith('/home') else 'messages'):
        with path.open('rb') as stream:
            stream.seek(max(0,path.stat().st_size-512*1024))
            lines=stream.read().decode(errors='replace').splitlines()
        selected=[s for s in lines if any(x in s.lower() for x in ('wireplumber','wp-','s-link','si-link','linkable','failed to activate','failed to load'))]
        print('ROUTING_LOG',path,'\n'+'\n'.join(selected[-35:]),flush=True)
for name in ('find-defined-target.lua','find-default-target.lua','prepare-link.lua','link-target.lua'):
    path=Path('/usr/share/wireplumber/scripts/linking')/name
    if path.exists():print('ROUTING_SCRIPT',name,'\n'+path.read_text(),flush=True)
PY
