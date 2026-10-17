#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
path=Path('/run/gta4l-camera-pipewire-test/wireplumber.log')
with path.open('rb') as stream:
    stream.seek(max(0,path.stat().st_size-512*1024))
    lines=stream.read().decode(errors='replace').splitlines()
selected=[s for s in lines if any(x in s for x in ('s-node','s-link','si-node','gta4l','python3','error','failed','Failed'))]
print('\n'.join(selected[-120:]),flush=True)
PY
