"""Package only isolated camera runtime files added or changed since r0."""
from pathlib import Path
import hashlib
import json
import tarfile
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--revision', type=int, default=1)
revision = parser.parse_args().revision
assert 1 <= revision <= 99

workspace = Path(__file__).resolve().parents[1]
source = Path('/home/ark/sm-t505-port/camera-development/runtime-root')
out = workspace/'artifacts/camera-development'
before = json.loads((out/'runtime-r0.json').read_text())['files']
for earlier in range(1, revision):
    before.update(json.loads((out/f'runtime-delta-r{earlier}.json').read_text())['files'])
archive = out/f'camera-runtime-delta-r{revision}.tar.gz'
files = {}
with tarfile.open(archive, 'w:gz', compresslevel=3) as tar:
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if path.is_symlink() or not path.is_file() or 'lib' in relative.parts: continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if before.get(str(relative), {}).get('sha256') == digest: continue
        files[str(relative)] = dict(size=path.stat().st_size, sha256=digest)
        tar.add(path, arcname=str(relative), recursive=False)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out/f'runtime-delta-r{revision}.json').write_text(json.dumps(dict(sha256=digest, files=files), indent=2)+'\n')
script = '''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib
import shutil
import tarfile
import os
archive = Path('/tmp/gta4l-upload/camera-runtime-delta-r__REV__.tar.gz')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '__HASH__'
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
'''.replace('__HASH__', digest).replace('__REV__', str(revision))
(workspace/f'tools/live-install-camera-runtime-delta-r{revision}.sh').write_text(script, newline='\n')
print('Packaged '+str(len(files))+' changed camera runtime files; '+str(archive.stat().st_size)+' bytes')
print('SHA256 '+digest)
