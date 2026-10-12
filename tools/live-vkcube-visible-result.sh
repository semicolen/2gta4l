#!/bin/sh
set -eu
[ "$(id -u)" = 10000 ]
python3 - <<'PY'
import os
import signal
from pathlib import Path

pid = int(Path('/home/tablet/.cache/gta4l/vkcube-visible.pid').read_text())
proc = Path(f'/proc/{pid}')
try:
    command = (proc / 'cmdline').read_bytes().split(b'\0')
    if proc.stat().st_uid == os.getuid() and command[:3] == [b'timeout', b'60', b'vkcube']:
        os.kill(pid, signal.SIGTERM)
        print('Stopped the verified, bounded cube test after physical confirmation.')
    else:
        print('Cube timeout has exited or PID is no longer its verified process; no signal sent.')
except FileNotFoundError:
    print('Cube timeout has already exited.')
print(Path('/home/tablet/.cache/gta4l/vkcube-visible.log').read_text())
print('VKCUBE_VISIBLE_RESULT_END')
PY
