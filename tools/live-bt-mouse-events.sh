#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json
import os
import select
import struct
import time

matches = []
for node in Path('/sys/class/input').glob('event*'):
    name = (node/'device/name').read_text().strip()
    if name == 'RAPOO BT4.0 Mouse Mouse':
        matches.append(Path('/dev/input')/node.name)
assert len(matches) == 1, 'Expected one RAPOO mouse input device'
fd = os.open(matches[0], os.O_RDONLY | os.O_NONBLOCK)
event = struct.Struct('llHHi')
assert event.size == 24, 'Expected ARM64 input_event layout'
counts = {'relative_motion': 0, 'button_press': 0, 'button_release': 0, 'wheel': 0}
deadline = time.monotonic()+25
print('RAPOO_INPUT_CAPTURE_STARTED', flush=True)
try:
    pending = bytearray()
    while time.monotonic() < deadline:
        if not select.select([fd], [], [], 0.25)[0]:
            continue
        pending.extend(os.read(fd, event.size*64))
        while len(pending) >= event.size:
            _, _, kind, code, value = event.unpack(pending[:event.size])
            del pending[:event.size]
            if kind == 2 and code in (0, 1) and value:
                counts['relative_motion'] += 1
            elif kind == 2 and code in (6, 8) and value:
                counts['wheel'] += 1
            elif kind == 1 and code in (272, 273, 274):
                if value == 1:
                    counts['button_press'] += 1
                elif value == 0:
                    counts['button_release'] += 1
finally:
    os.close(fd)
print(json.dumps(counts, sort_keys=True))
print('RAPOO_INPUT_CAPTURE_FINISHED')
PY
