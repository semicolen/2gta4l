#!/bin/sh
set -eu
partition=
for entry in /sys/class/block/mmcblk0p*/uevent; do
    if grep -q '^PARTNAME=sec_efs$' "$entry"; then
        [ -z "$partition" ]
        partition="/dev/$(sed -n 's/^DEVNAME=//p' "$entry")"
    fi
done
[ "$partition" = /dev/mmcblk0p63 ]
[ -b "$partition" ]
# debugfs is opened without -w, so the calibration partition is read-only.
debugfs -R 'cat /bluetooth/bt_addr' "$partition" 2>/tmp/gta4l-bt-address-read.log > /tmp/gta4l-bt-stock-address
python3 - <<'PY'
from pathlib import Path
import re
p = Path('/tmp/gta4l-bt-stock-address')
raw = p.read_bytes().strip(b'\x00\n\r ')
if len(raw) == 6:
    address = raw
else:
    text = raw.decode('ascii').strip()
    assert re.fullmatch(r'[0-9A-Fa-f]{12}|(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', text)
    address = bytes.fromhex(text.replace(':', ''))
assert len(address) == 6 and address not in [bytes(6), b'\xff'*6]
assert not address[0] & 1, 'Expected unicast Bluetooth address'
target = Path('/var/lib/gta4l/bluetooth-address')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(':'.join(f'{b:02X}' for b in address) + '\n')
target.chmod(0o600)
p.unlink()
print('STOCK_BLUETOOTH_ADDRESS_READ_ONLY_PROVISIONED')
PY
