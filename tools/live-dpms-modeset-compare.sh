#!/bin/sh
set -eu
python3 - <<'PY'
import os
import select
import subprocess
import threading
import time
from pathlib import Path

env = dict(os.environ, DISPLAY=':0', XAUTHORITY='/var/run/lightdm/root/:0')
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

def marker(label):
    with open('/dev/kmsg', 'w') as kernel:
        kernel.write('GTA4L_MODESET_COMPARE_' + label + '\n')

def run(*args):
    print('COMMAND:', *args, flush=True)
    subprocess.run(args, env=env, check=True, timeout=10)

thread = threading.Thread(target=capture)
thread.start()
try:
    # SDE KMS logs also require the core category (DRM_DEBUG).
    parameter.write_text('85\n')
    marker('DPMS_BEGIN')
    run('xset', '+dpms')
    run('xset', 'dpms', 'force', 'off')
    time.sleep(1)
    run('xset', 'dpms', 'force', 'on')
    time.sleep(1)
    marker('DPMS_END')
    run('xset', '-dpms')
    marker('FULL_MODESET_BEGIN')
    run('xrandr', '--output', 'DSI-1', '--off')
    time.sleep(1)
    run('xrandr', '--output', 'DSI-1', '--auto', '--primary', '--rotate', 'inverted')
    time.sleep(1)
    marker('FULL_MODESET_END')
finally:
    parameter.write_text(original)
    time.sleep(0.2)
    stop.set()
    thread.join(2)
    os.close(fd)
output = b''.join(chunks)
Path('/var/log/gta4l/dpms-modeset-compare.log').write_bytes(output)
print('Captured:', saved, 'of', received, 'bytes', flush=True)
print(output.decode(errors='replace'), flush=True)
print('MODESET_COMPARE_END')
PY
