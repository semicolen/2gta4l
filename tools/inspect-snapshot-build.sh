#!/bin/sh
set -eu
tail -n 12 /home/ark/sm-t505-port/work/log.txt
python3 - <<'PY'
from pathlib import Path
processes=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip()=='rustc':
            processes.append((p.name,str((p/'exe').resolve())))
    except (OSError,ProcessLookupError):pass
print('RUST_COMPILER_EXECUTABLES',processes[:3])
with Path('/home/ark/sm-t505-port/work/log.txt').open('rb') as stream:
    stream.seek(0,2);stream.seek(max(0,stream.tell()-80000));tail=stream.read().decode(errors='replace')
milestones=[line for line in tail.splitlines() if any(mark in line for mark in ('Finished `','test result:','>>> snapshot: Entering','>>> snapshot: Running','ERROR: snapshot:'))]
print('CAMERA_BUILD_MILESTONES','\n'.join(milestones[-8:]))
PY
