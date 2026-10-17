#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
path=Path('/etc/libinput/local-overrides.quirks')
if path.exists():
    data=path.read_text()
    assert not any(line.strip() and not line.lstrip().startswith('#') for line in data.splitlines()),'Refuse to remove nonempty user overrides'
    backup=Path('/var/lib/gta4l-ui-qc/empty-quirks-before-cleanup.txt')
    backup.write_bytes(path.read_bytes())
    path.unlink()
    os.sync()
    print('Removed comments-only experimental quirks file; libinput requires actual sections or no file',flush=True)
PY
libinput quirks list /dev/input/event1
echo INPUT_QUIRKS_DATABASE_VALID
