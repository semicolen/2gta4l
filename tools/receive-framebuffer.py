#!/usr/bin/env python3
"""Read the fixed-size tablet framebuffer through its direct USB link."""
from pathlib import Path
import socket
from PIL import Image

target = Path('evidence/diagnostic-boot-20261009/staged5-framebuffer')
data = bytearray()
with socket.create_connection(('172.16.42.1', 2426), timeout=5) as client:
    client.settimeout(10)
    while len(data) < 4864 * 2000:
        block = client.recv(min(65536, 4864 * 2000 - len(data)))
        if not block:
            break
        data.extend(block)
target.with_suffix('.raw').write_bytes(data)
assert len(data) == 4864 * 2000, f'Incomplete capture: {len(data)}'
Image.frombytes('RGB', (1216, 2000), bytes(data), 'raw', 'BGRX').crop((0, 0, 1200, 2000)).save(target.with_suffix('.png'))
print(f'Saved {len(data)} framebuffer bytes')
