#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,signal,pwd
uid=pwd.getpwnam('tablet').pw_uid
for path in Path('/proc').iterdir():
    if not path.name.isdigit():continue
    try:
        if path.stat().st_uid!=uid:continue
        args=(path/'cmdline').read_bytes().split(b'\0')
        if b'/usr/bin/gta4l-camera' in args:
            raise SystemExit('Close Camera before upgrading it')
        if b'/home/tablet/.cache/gta4l-camera/review.py' in args:
            os.kill(int(path.name),signal.SIGTERM)
    except (FileNotFoundError,ProcessLookupError):pass
print('CAMERA_TEST_REVIEW_WINDOWS_CLOSED')
PY
timeout --help 2>&1 | head -n 8
printf 'CAMERA_BEFORE_R2_END\n'
