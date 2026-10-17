#!/bin/sh
set -eu
rc-service tinydm stop
rc-service networkmanager stop
rc-service modemmanager stop || true
rc-service polkit stop || true
python3 - <<'PY'
import os
from pathlib import Path
import signal
import time
for process in Path('/proc').iterdir():
    if not process.name.isdigit():
        continue
    try:
        command = (process / 'cmdline').read_bytes().split(b'\0')
        if command and command[0] == b'/usr/lib/polkit-1/polkitd':
            os.kill(int(process.name), signal.SIGTERM)
            print('Stopped leftover D-Bus-activated authority:', process.name)
    except (FileNotFoundError, ProcessLookupError):
        pass
time.sleep(2)
PY
rc-service polkit start
rc-service modemmanager start
rc-service gta4l-dbus-services start
rc-service networkmanager start
rc-service tinydm start
sleep 3
rc-service polkit status
printf '\nORDERED_AUTHORIZATION_RESTART_END\n'
