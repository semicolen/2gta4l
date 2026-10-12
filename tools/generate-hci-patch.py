#!/usr/bin/env python3
"""Restore the HCI implementation from the matching Linux stable release."""
from pathlib import Path
import difflib
import hashlib

native = Path('/home/pmos/sm-t505-port')
workspace = Path('/mnt/c/postmarketOS-gta4l')
vendor = (native / 'kernel/net/bluetooth/hci_sock.c').read_text()
upstream_path = native / 'downloads/hci_sock-linux-v4.19.300.c'
upstream = upstream_path.read_text()
assert 'static int hci_sock_create' in upstream
assert 'sock_init_data(sock, sk);' in upstream
assert 'static DEFINE_IDA(sock_cookie_ida);' in upstream
patch = ''.join(difflib.unified_diff(vendor.splitlines(True), upstream.splitlines(True),
    fromfile='a/net/bluetooth/hci_sock.c', tofile='b/net/bluetooth/hci_sock.c'))
header = '''Subject: [PATCH] Bluetooth: restore the Linux 4.19.300 HCI socket implementation

The vendor tree comments out HCI socket allocation and returns success.
BlueZ's first socket(AF_BLUETOOTH, SOCK_RAW, BTPROTO_HCI) consequently
passes a NULL sock->sk to bt_sock_reclassify_lock and trips BUG_ON(!sk).
Restore the matching stable implementation, including allocation, release,
bind, ioctl, message handling and monitor-cookie lifetime management.

Upstream source:
https://github.com/gregkh/linux/blob/v4.19.300/net/bluetooth/hci_sock.c
'''
header += '\nUpstream file SHA256: ' + hashlib.sha256(upstream_path.read_bytes()).hexdigest() + '\n\n'
target = workspace / 'port/linux-samsung-gta4l/restore-hci-sockets.patch'
target.write_text(header + patch, newline='\n')
print(f'Wrote {len(patch.splitlines())} patch lines; upstream SHA256={hashlib.sha256(upstream_path.read_bytes()).hexdigest()}')
