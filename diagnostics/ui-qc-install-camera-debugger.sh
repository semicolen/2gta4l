#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import subprocess
def versions():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        v=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in v:result[v['P']]=v['V']
    return result
before=versions();expected={'musl-dbg','libdw','libdebuginfod','gdb'}
trial=subprocess.run(['apk','--simulate','add','gdb'],capture_output=True,text=True,timeout=20)
assert trial.returncode==0,trial.stderr
for line in trial.stdout.splitlines():
    if any(word in line for word in ('Upgrading ','Downgrading ','Replacing ','Purging ','Removing ')):raise RuntimeError(line)
    if 'Installing ' in line:assert any('Installing '+name+' (' in line for name in expected),line
subprocess.run(['apk','--no-interactive','--no-scripts','add','gdb'],check=True,timeout=45)
after=versions()
assert all(after[k]==v for k,v in before.items())
assert set(after)-set(before)<=expected
print('CAMERA_DEBUGGER_ADDED_EXISTING_PACKAGES_UNCHANGED',flush=True)
PY
