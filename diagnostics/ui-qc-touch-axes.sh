#!/bin/sh
set -eu
python3 - <<'PY'
import array
import fcntl
import os
from pathlib import Path

for event in Path('/sys/class/input').glob('event*'):
    if (event / 'device/name').read_text().strip() != 'himax-touchscreen':
        continue
    print('Touchscreen:', event.name)
    print('Udev data:')
    import subprocess
    subprocess.run(['udevadm', 'info', '--query=property', '--path=' + str(event)], check=True)
    fd = os.open('/dev/input/' + event.name, os.O_RDONLY | os.O_NONBLOCK)
    try:
        for name, code in [('ABS_X', 0), ('ABS_Y', 1), ('ABS_MT_POSITION_X', 0x35), ('ABS_MT_POSITION_Y', 0x36)]:
            values = array.array('i', [0] * 6)
            fcntl.ioctl(fd, 0x80184540 + code, values, True)
            print(name, dict(zip(('value', 'minimum', 'maximum', 'fuzz', 'flat', 'resolution'), values)))
    finally:
        os.close(fd)
PY
