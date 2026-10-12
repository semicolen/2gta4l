#!/bin/sh
set -eu
bluetoothctl show | grep -q 'Powered: yes'
timeout 14 bluetoothctl --timeout 10 scan on > /var/log/gta4l/bluetooth-rapoo-scan.log 2>&1
python3 - <<'PY'
import re
import subprocess
from pathlib import Path
data = subprocess.check_output(['bluetoothctl', 'devices'], text=True)
data = re.sub(r'\x1b\[[0-9;]*m', '', data)
candidates = []
for line in data.splitlines():
    match = re.fullmatch(r'Device ([0-9A-F]{2}(?::[0-9A-F]{2}){5}) (.+)', line)
    if match and 'RAPOO' in match[2].upper():
        print('RAPOO_CANDIDATE='+line)
        if 'BT4.0' in match[2].upper():
            candidates.append(match[1])
if len(candidates) == 1:
    Path('/run/gta4l-rapoo-address').write_text(candidates[0]+'\n')
    print(subprocess.check_output(['bluetoothctl', 'info', candidates[0]], text=True))
else:
    print('RAPOO_BT4_CANDIDATE_COUNT='+str(len(candidates)))
PY
echo RAPOO_DISCOVERY_END
