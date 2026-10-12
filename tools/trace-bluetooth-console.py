#!/usr/bin/env python3
"""Capture Bluetooth-only debug/syscall output over the USB console."""
from pathlib import Path
import os
import sys
import telnetlib
import time

output = Path(sys.argv[1])
command = b"stty -echo; echo 'GTA4L_STAGE: isolated bluetoothd under strace' >/dev/kmsg; LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -f -tt -s 128 -e trace=socket,bind,connect,setsockopt,getsockopt,ioctl,sendmsg,sendto,recvmsg,recvfrom -e inject=socket,bind,connect,setsockopt,ioctl,sendmsg,sendto:delay_enter=100ms /usr/lib/bluetooth/bluetoothd --nodetach --debug\n"
deadline = time.monotonic() + 60
with telnetlib.Telnet('172.16.42.1', 2323, timeout=3) as console, output.open('wb') as saved:
    console.write(b'\r\n')
    initial = console.read_until(b'# ', timeout=3)
    saved.write(initial)
    console.write(command)
    print('Tracing isolated Bluetooth startup', flush=True)
    while time.monotonic() < deadline:
        try:
            data = console.read_very_eager()
        except (EOFError, OSError):
            print('Bluetooth trace console disconnected', flush=True)
            break
        if data:
            saved.write(data)
            saved.flush()
            os.fsync(saved.fileno())
        else:
            time.sleep(0.03)
    print(f'Saved Bluetooth trace to {output}', flush=True)
