#!/bin/sh
set -eu
DIR=/home/ark/sm-t505-port/stock/vendor/inspect
curl -fsSL 'https://api.github.com/repos/LineageOS/android_vendor_qcom_opensource_bluetooth/git/trees/cm-14.1?recursive=1' -o "$DIR/bluetooth-source-tree.json"
python3 - <<'PY'
import json
from pathlib import Path
p = Path('/home/ark/sm-t505-port/stock/vendor/inspect')
data = json.loads((p/'bluetooth-source-tree.json').read_text())
for entry in data.get('tree', []):
    if any(x in entry['path'] for x in ['patch_dl', 'rome', 'uart_controller']):
        print(entry['path'])
PY
