#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib
import shutil
import tarfile
import os
archive = Path('/tmp/gta4l-upload/camera-runtime-delta-r1.tar.gz')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '9610104fdef7ae88b3c09ad30ab35e63f4ad98af2fd488bcfdd6e8475271774b'
root = Path('/opt/gta4l-camera-dev/r0')
assert root.is_dir() and not root.is_symlink()
hal = root/'vendor/lib64/hw/camera.qcom.so'
assert hashlib.sha256(hal.read_bytes()).hexdigest() == '3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8'
with tarfile.open(archive) as tar:
    for member in tar:
        relative = Path(member.name)
        assert member.isfile() and not relative.is_absolute() and '..' not in relative.parts
        target = root/relative
        assert not target.is_symlink()
        for ancestor in target.parents:
            if ancestor == root: break
            assert not ancestor.is_symlink()
        target.parent.mkdir(parents=True, exist_ok=True)
        with tar.extractfile(member) as src, target.open('wb') as dst:
            shutil.copyfileobj(src, dst)
        os.chmod(target, member.mode & 0o777)
print('CAMERA_RUNTIME_DELTA_INSTALLED')
PY
