#!/usr/bin/env python3
"""Receive read-only kernel records without a terminal or Telnet transport."""
from pathlib import Path
import os
import re
import socket
import sys
import time

output = Path(sys.argv[1])
deadline = time.monotonic() + (int(sys.argv[2]) if len(sys.argv) > 2 else 100)
total = 0
tail = b''
with socket.create_connection(('172.16.42.1', 2425), timeout=3) as console, output.open('wb') as saved:
    console.settimeout(1)
    print('Connected to static kernel recorder', flush=True)
    while time.monotonic() < deadline:
        try:
            data = console.recv(65536)
        except socket.timeout:
            continue
        except OSError as error:
            print(f'Kernel stream disconnected: {error}', flush=True)
            break
        if not data:
            print('Kernel stream closed by tablet', flush=True)
            break
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
