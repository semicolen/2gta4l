#!/bin/sh
set -eu
python3 - <<'PY'
import subprocess
devices = subprocess.check_output(['bluetoothctl', 'devices'], text=True, timeout=5)
matches = []
for line in devices.splitlines():
    parts = line.split(' ', 2)
    if len(parts) == 3 and parts[0] == 'Device':
        name = parts[2]
        if name.upper().replace('_', '-') == 'LENOVO-IDEAPAD1':
            matches.append(parts[1])
assert len(matches) <= 1, 'More than one named Lenovo peer'
for address in matches:
    subprocess.run(['bluetoothctl', 'info', address], check=True, timeout=5)
if not matches:
    print('No named Lenovo peer in BlueZ device cache')
PY
echo '=== NetworkManager Bluetooth devices ==='
nmcli -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION device show | grep -A 3 -B 1 -E 'bluetooth|LENOVO' || true
echo LENOVO_BLUETOOTH_STATE_END
