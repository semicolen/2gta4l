#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib
import shutil
import tarfile
import os
archive = Path('/tmp/gta4l-upload/camera-runtime-r0.tar.gz')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '93b454a2869a0a9934b9c50195512706dc2b90f2aa0c4604e383f8c7faf3e283'
base = Path('/opt/gta4l-camera-dev')
assert not base.is_symlink()
base.mkdir(mode=0o700, exist_ok=True)
os.chmod(base, 0o700)
root = base/'r0'
root.mkdir(mode=0o700)  # Refuse to overwrite an existing test tree.
with tarfile.open(archive) as tar:
    for member in tar:
        assert member.isfile() and not Path(member.name).is_absolute()
        assert '..' not in Path(member.name).parts
        target = root/member.name
        target.parent.mkdir(parents=True, exist_ok=True)
        with tar.extractfile(member) as src, target.open('xb') as dst:
            shutil.copyfileobj(src, dst)
        os.chmod(target, member.mode & 0o777)
print('ISOLATED_CAMERA_RUNTIME_INSTALLED')
PY
LD_LIBRARY_PATH=/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/apex/com.android.vndk.v31/lib64:/system/lib64 \
    timeout 12 chroot /opt/gta4l-camera-dev/r0 /system/bin/camera-hal-enumerate --smoke
printf 'CAMERA_RUNTIME_SMOKE_END\n'
