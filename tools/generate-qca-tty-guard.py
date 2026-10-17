#!/usr/bin/env python3
from pathlib import Path
import difflib

root = Path(__file__).resolve().parents[1]
source = Path('/home/ark/sm-t505-port/kernel/drivers/bluetooth/hci_qca.c').read_text()
needle = '''\tBT_DBG("hu %p qca_open", hu);

\tif (!hci_uart_has_flow_control(hu))'''
replacement = '''\tBT_DBG("hu %p qca_open", hu);

\t/* This downstream setup requires serdev, including its power and
\t * firmware paths. Reject tty attachment before allocating work that
\t * would later dereference hu->serdev. SM-T505 uses a userspace
\t * WCN3988 bootstrap followed by the standard H4 transport.
\t */
\tif (!hu->serdev)
\t\treturn -EOPNOTSUPP;

\tif (!hci_uart_has_flow_control(hu))'''
assert source.count(needle) == 1
updated = source.replace(needle, replacement)
patch = ''.join(difflib.unified_diff(source.splitlines(True), updated.splitlines(True),
                                    fromfile='a/drivers/bluetooth/hci_qca.c',
                                    tofile='b/drivers/bluetooth/hci_qca.c'))
(root/'port/linux-samsung-gta4l/guard-qca-tty.patch').write_text(patch, newline='\n')
print('Generated guard rejecting unsupported downstream QCA tty setup')
