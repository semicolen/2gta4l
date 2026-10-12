#!/usr/bin/env python3
"""Save the live kernel-only stream from the tablet's direct USB interface."""
from pathlib import Path
import os
import re
import sys
import telnetlib
import time

output = Path(sys.argv[1])
deadline = time.monotonic() + 75
total = 0
tail = b''
with telnetlib.Telnet('172.16.42.1', 2424, timeout=3) as console, output.open('wb') as saved:
    console.get_socket().settimeout(1)
    print('Connected to live kernel stream', flush=True)
    while time.monotonic() < deadline:
        try:
            data = console.read_very_eager()
        except (EOFError, OSError):
            print('Kernel stream disconnected', flush=True)
            break
        if not data:
            time.sleep(0.03)
            continue
        saved.write(data)
        saved.flush()
        os.fsync(saved.fileno())
        total += len(data)
        lines = (tail + data).splitlines(keepends=True)
        tail = lines.pop() if lines and not lines[-1].endswith((b'\r', b'\n')) else b''
        for line in lines:
            if re.search(rb'Kernel panic|BUG:|Oops:|Unable to handle kernel|Internal error:', line):
                print(line.decode('utf-8', errors='replace').strip(), flush=True)
    print(f'Saved {total} kernel bytes to {output}', flush=True)
