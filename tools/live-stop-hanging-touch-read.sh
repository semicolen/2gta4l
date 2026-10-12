#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
import signal
expected = [b'cat', b'/sys/class/sec/tsp/cmd_status', b'/sys/class/sec/tsp/cmd_result', b'/proc/android_touch/SMWP']
for process in Path('/proc').iterdir():
    if not process.name.isdigit():
        continue
    try:
        arguments = (process / 'cmdline').read_bytes().rstrip(b'\0').split(b'\0')
        if arguments == expected:
            os.kill(int(process.name), signal.SIGTERM)
            print('Stopped the hanging touch diagnostic read:', process.name)
    except (FileNotFoundError, ProcessLookupError):
        pass
PY
