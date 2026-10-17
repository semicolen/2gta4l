#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,os
assert os.geteuid()==0
data=Path('/tmp/gta4l-upload/snapshot-shutter-r1-candidate').read_bytes()
assert hashlib.sha256(data).hexdigest()=='376220ed29c4bf1455de9eedfef3927ccf8f8531b4f5a5a610bef3938cb96713'
assert data[:4]==b'\x7fELF' and int.from_bytes(data[18:20],'little')==183
run=Path('/run/gta4l-snapshot-candidate');run.mkdir(mode=0o755,exist_ok=True)
assert not run.is_symlink() and run.stat().st_uid==0
binary=run/'snapshot';assert not binary.is_symlink()
binary.write_bytes(data);binary.chmod(0o755)
print('ARM64_SNAPSHOT_CANDIDATE_STAGED_INSTALLED_EXECUTABLE_UNCHANGED',flush=True)
PY
