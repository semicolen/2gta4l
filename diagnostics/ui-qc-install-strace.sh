#!/bin/sh
set -eu
printf '%s\n' '7f5f5c674aa32287926d3d13e766d7ef2bec3cfc97bdeb42f3352464bba836a8  /tmp/gta4l-upload/strace-7.2-r0.apk' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import subprocess
def packages():
    out={}
    for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        values=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if 'P' in values:out[values['P']]=values['V']
    return out
before=packages()
args=['apk','add','--no-network','/tmp/gta4l-upload/strace-7.2-r0.apk',
      '/tmp/gta4l-upload/libdw-0.195-r0.apk','/tmp/gta4l-upload/libelf-0.195-r0.apk']
trial=subprocess.run(args[:2]+['--simulate']+args[2:],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(trial.stdout,flush=True)
assert trial.returncode==0,'Offline dependency resolution failed; no packages changed'
assert not any(word in trial.stdout for word in ('Purging','Removing','Upgrading','Downgrading'))
subprocess.run(args,check=True)
after=packages()
assert all(after.get(k)==v for k,v in before.items())
assert set(after)-set(before)<= {'strace','libdw','libelf'}
print('TRACING_TOOLS_ONLY_ADDED; existing packages unchanged',flush=True)
PY
