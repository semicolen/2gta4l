#!/bin/sh
set -eu
printf '=== Recent kernel camera/GPU errors ===\n'
dmesg | grep -E 'kgsl|firmware|a610|sqe|adreno|cam_req_mgr|cam_ife' | tail -60
python3 - <<'PY'
from pathlib import Path
for name in ('/lib/firmware','/usr/lib/firmware','/opt/gta4l-camera-dev/r0/lib/firmware'):
    p=Path(name)
    print(name+' exists='+str(p.exists())+' real='+str(p.resolve()))
    if p.exists():
        for q in p.rglob('*a6*'):
            print(str(q))
PY
printf 'CAMERA_GPU_FIRMWARE_DIAGNOSE_END\n'
