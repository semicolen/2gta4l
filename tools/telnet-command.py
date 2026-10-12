#!/usr/bin/env python3
"""Read the tablet's unencrypted initramfs console over its direct USB link."""
from pathlib import Path
import sys
import telnetlib

command = Path(sys.argv[1]).read_bytes().replace(b'\r', b'')
output = Path(sys.argv[2])
marker = sys.argv[3].encode()
port = int(sys.argv[4]) if len(sys.argv) > 4 else 23
with telnetlib.Telnet('172.16.42.1', port, timeout=3) as console:
    console.write(b'\r\n')
    initial = console.read_until(b'# ', timeout=3)
    console.write(command + b'\n')
    try:
        result = initial + console.read_until(b'\n' + marker + b'\r', timeout=15)
    except OSError:
        result = initial + console.read_very_lazy()
output.write_bytes(result)
complete = b'\n' + marker + b'\r' in result
# Continuing boot tears down telnet before the caller can print its end marker.
if marker == b'GTA4L_CONTINUE_REQUESTED' and b'Continuing boot...' in result:
    complete = True
if marker == b'GTA4L_RECOVERY_REBOOT_END' and b'Requesting vendor recovery reboot' in result:
    complete = True
assert complete, 'Incomplete console response'
print(f'Saved {len(result)} console bytes to {output}')
