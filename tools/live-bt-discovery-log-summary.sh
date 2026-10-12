#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import re
data = Path('/var/log/gta4l/bluetooth-scan-test.log').read_text()
data = re.sub(r'[0-9A-F]{2}(?::[0-9A-F]{2}){5}', '[address]', data)
print(data[:8000])
PY
command -v btmon || true
command -v btmgmt || true
