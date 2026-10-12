#!/usr/bin/env python3
"""Bounded wait for the tablet USB SSH port after an authorized reboot."""
import socket
import time

deadline = time.monotonic() + 45
while time.monotonic() < deadline:
    try:
        with socket.create_connection(('172.16.42.1', 22), timeout=2):
            print('Tablet USB SSH port is available')
            break
    except OSError:
        time.sleep(2)
else:
    raise SystemExit('Tablet USB SSH port did not return within 45 seconds')
