"""Package an isolated camera development runtime; never flashes partitions."""
from pathlib import Path
import hashlib
import json
import tarfile

workspace = Path(__file__).resolve().parents[1]
source = Path('/home/ark/sm-t505-port/camera-development/runtime-root')
out = workspace/'artifacts/camera-development'
out.mkdir(exist_ok=True)
archive = out/'camera-runtime-r0.tar.gz'
files = {}
with tarfile.open(archive, 'w:gz', compresslevel=3) as tar:
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if path.is_symlink() or not path.is_file() or 'lib' in relative.parts:
            continue
        data = path.read_bytes()
        files[str(relative)] = dict(size=len(data), sha256=hashlib.sha256(data).hexdigest())
        tar.add(path, arcname=str(relative), recursive=False)
assert 'system/bin/camera-hal-enumerate' in files
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
manifest = dict(archive=archive.name, sha256=digest, files=files,
    stock_version='T505XXS8CXG1', locally_built_helper=True,
    camera_capture_verified=False)
(out/'runtime-r0.json').write_text(json.dumps(manifest, indent=2)+'\n')
install = '''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib
import shutil
import tarfile
import os
archive = Path('/tmp/gta4l-upload/camera-runtime-r0.tar.gz')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '__HASH__'
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
LD_LIBRARY_PATH=/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/apex/com.android.vndk.v31/lib64:/system/lib64 \\
    timeout 12 chroot /opt/gta4l-camera-dev/r0 /system/bin/camera-hal-enumerate --smoke
printf 'CAMERA_RUNTIME_SMOKE_END\\n'
'''.replace('__HASH__', digest)
(workspace/'tools/live-install-camera-runtime-r0.sh').write_text(install, newline='\n')
print('Packaged isolated camera development runtime: '+str(archive.stat().st_size)+' bytes')
print('SHA256 '+digest)
