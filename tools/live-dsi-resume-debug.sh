#!/bin/sh
set -eu
python3 - <<'PY'
import os
import select
import subprocess
import threading
import time
from pathlib import Path

parameter = Path('/sys/module/drm/parameters/debug')
original = parameter.read_text()
stop = threading.Event()
chunks = []
saved = 0
received = 0
fd = os.open('/dev/kmsg', os.O_RDONLY | os.O_NONBLOCK)
os.lseek(fd, 0, os.SEEK_END)

def capture():
    global saved, received
    while not stop.is_set():
        ready, _, _ = select.select([fd], [], [], 0.1)
        if not ready:
            continue
        try:
            record = os.read(fd, 65536)
        except BlockingIOError:
            continue
        except OSError:
            continue
        received += len(record)
        keep = record[:max(0, 2 * 1024 * 1024 - saved)]
        if keep:
            chunks.append(keep)
            saved += len(keep)

thread = threading.Thread(target=capture)
thread.start()
env = dict(os.environ, DISPLAY=':0', XAUTHORITY='/var/run/lightdm/root/:0')
try:
    parameter.write_text('1\n')
    with open('/dev/kmsg', 'w') as kernel:
        kernel.write('GTA4L_RESUME_DEBUG_START\n')
    subprocess.run(['xset', 'dpms', 'force', 'off'], env=env, check=True, timeout=10)
    time.sleep(1)
    subprocess.run(['xset', 'dpms', 'force', 'on'], env=env, check=True, timeout=10)
    time.sleep(1)
    Path('/sys/class/backlight/panel0-backlight/brightness').write_text('131\n')
    time.sleep(0.2)
finally:
    parameter.write_text(original)
    time.sleep(0.1)
    stop.set()
    thread.join(2)
    os.close(fd)
output = b''.join(chunks)
Path('/var/log/gta4l/panel-resume-debug.log').write_bytes(output)
print('Captured runtime DSI debug:', saved, 'of', received, 'bytes', flush=True)
print(output.decode(errors='replace'), flush=True)
print('DSI_DEBUG_END')
PY
