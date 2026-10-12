#!/bin/sh
set -eu
pgrep -af 'gta4l-camera/review.py' || true
cat /home/tablet/.cache/gta4l-camera/review.log
printf '=== Captured file metadata ===\n'
python3 - <<'PY'
from pathlib import Path
import hashlib
for name in ('rear','front'):
    p=Path('/opt/gta4l-camera-dev/r0/data/vendor/camera')/(name+'.ppm')
    data=p.read_bytes()
    print(name+' bytes='+str(len(data))+' sha256='+hashlib.sha256(data).hexdigest()+' header='+repr(data[:15]))
print('boot_id='+Path('/proc/sys/kernel/random/boot_id').read_text().strip())
PY
printf 'CAMERA_REVIEW_STATE_END\n'
