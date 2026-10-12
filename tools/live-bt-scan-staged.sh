#!/bin/sh
set -eu
for radio in /sys/class/rfkill/rfkill*; do
    if [ "$(cat "$radio/name")" = hci0 ]; then echo 0 > "$radio/soft"; fi
done
# Clearing rfkill can trigger BlueZ's automatic power-on before this command.
bluetoothctl power on || true
sleep 2
bluetoothctl show | grep -q 'Powered: yes'
bluetoothctl show
set +e
timeout 14 bluetoothctl --timeout 10 scan on > /var/log/gta4l/bluetooth-scan-test.log 2>&1
scan_status=$?
set -e
bluetoothctl scan off || true
echo "BT_SCAN_COMMAND_STATUS=$scan_status"
python3 - <<'PY'
from pathlib import Path
import re
data = Path('/var/log/gta4l/bluetooth-scan-test.log').read_text()
data = re.sub(r'\x1b\[[0-9;]*m', '', data)
print('BT_DISCOVERY_STARTED='+str('Discovery started' in data or 'Discovering: yes' in data))
devices = set(re.findall(r'\[NEW\] Device ([0-9A-F]{2}(?::[0-9A-F]{2}){5})', data))
print('BT_DISCOVERED_DEVICE_COUNT='+str(len(devices)))
print('BT_SCAN_LOG_ERRORS='+str(bool(re.search(r'Failed|Error|not available', data))))
PY
dmesg | grep -E 'Bluetooth:|ttyHS0.*(error|fault)' | tail -n 25
ps | grep -E '[b]tattach|[g]ta4l-bt-initialize'
echo BT_STAGED_SCAN_END
