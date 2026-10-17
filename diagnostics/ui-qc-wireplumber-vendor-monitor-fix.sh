#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
assert os.geteuid()==0
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip()=='wireplumber':
            print('WP_THREAD_WAIT_STATES',[(t.name,(t/'comm').read_text().strip(),(t/'wchan').read_text().strip()) for t in (p/'task').iterdir()],flush=True)
    except (OSError,ProcessLookupError):pass
path=Path('/etc/wireplumber/wireplumber.conf.d/60-gta4l-camera.conf')
assert not path.exists()
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text('''# Samsung camera nodes are owned by the stock-HAL broker.
# Standard clients use the broker-backed PipeWire video sources.
wireplumber.profiles = {
  main = {
    monitor.libcamera = disabled
    monitor.v4l2 = disabled
  }
}
''')
path.chmod(0o644)
print('DISABLED_GENERIC_VENDOR_NODE_PROBING_STANDARD_ROUTING_PRESERVED',flush=True)
PY
