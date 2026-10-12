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
fd = os.open('/dev/kmsg', os.O_RDONLY | os.O_NONBLOCK)
os.lseek(fd, 0, os.SEEK_END)
stop = threading.Event()
chunks = []
saved = 0
received = 0

def capture():
    global saved, received
    while not stop.is_set():
        if not select.select([fd], [], [], 0.1)[0]:
            continue
        try:
            record = os.read(fd, 65536)
        except (BlockingIOError, OSError):
            continue
        received += len(record)
        keep = record[:max(0, 1800000 - saved)]
        chunks.append(keep)
        saved += len(keep)

thread = threading.Thread(target=capture)
thread.start()
env = dict(os.environ, DISPLAY=':0', XAUTHORITY='/var/run/lightdm/root/:0')
try:
    parameter.write_text('85\n')
    with open('/dev/kmsg', 'w') as kernel:
        kernel.write('GTA4L_PLANE_RESUME_TEST_START\n')
    subprocess.run(['xset', '+dpms'], env=env, check=True, timeout=10)
    subprocess.run(['xset', 'dpms', 'force', 'off'], env=env, check=True, timeout=10)
    time.sleep(3)
    subprocess.run(['xset', 'dpms', 'force', 'on'], env=env, check=True, timeout=10)
    time.sleep(2)
    subprocess.run(['xset', 'q'], env=env, check=True, timeout=10)
finally:
    parameter.write_text(original)
    time.sleep(0.1)
    stop.set()
    thread.join(2)
    os.close(fd)
output = b''.join(chunks)
Path('/var/log/gta4l/plane-resume-test.log').write_bytes(output)
print('Captured:', saved, 'of', received, 'bytes', flush=True)
print(output.decode(errors='replace'), flush=True)
print('PLANE_RESUME_TEST_END')
PY
