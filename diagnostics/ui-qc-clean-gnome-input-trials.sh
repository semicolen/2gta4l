#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,re,signal,time
assert os.geteuid()==0
target=Path('/etc/libinput/local-overrides.quirks')
if target.exists():
    old=target.read_text()
    new=re.sub(r'\[Galaxy Tab A7 Himax touchscreen\]\n.*?(?=\n\[|\Z)','',old,flags=re.S)
    assert old!=new,'Expected only the staged Himax test section to be removed'
    if any(line.strip() and not line.lstrip().startswith('#') for line in new.splitlines()):
        target.write_text(new);target.chmod(0o644)
    else:
        # libinput rejects an empty local quirks file; restore its absence.
        target.unlink()
    print('Removed the experimental Himax libinput section; unrelated sections retained',flush=True)
pidfile=Path('/run/gta4l-ui-qc/tablet-mode.pid')
if pidfile.exists():
    pid=int(pidfile.read_text())
    process=Path('/proc')/str(pid)
    if process.exists():
        assert (process/'cmdline').read_bytes().split(b'\0')[0]==b'/run/gta4l-ui-qc/tablet-mode-helper'
        os.kill(pid,signal.SIGTERM)
        for unused in range(40):
            if not process.exists():break
            time.sleep(0.1)
        assert not process.exists(),'Tablet-mode trial did not exit'
    print('Stopped temporary fixed tablet-mode input device',flush=True)
print('GNOME_INPUT_TRIAL_CLEANUP_COMPLETE',flush=True)
PY
