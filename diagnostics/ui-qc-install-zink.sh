#!/bin/sh
set -eu
printf '%s\n' 'b9c03e365f9406f09ddbc2c29f89c89be287e477f9acf8b71732a168f9fdecb4  /tmp/gta4l-upload/mesa-zink-kgsl-gta4l-26.0.8-r3.apk' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import json,subprocess
def packages():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in values:result[values['P']]=values['V']
    return result
before=packages()
assert before['mesa-vulkan-kgsl-gta4l']=='26.2.4-r0'
retain=['mesa','mesa-dri-gallium','mesa-egl','mesa-gl','mesa-gles','mesa-gbm',
        'gnome-keyring','gnome-keyring-pam','gnome-keyring-openrc','gnome-keyring-lang',
        'gcr','gcr-base','gcr-lang']
retain=[name for name in retain if name in before]
assert all(name in before for name in ('mesa-dri-gallium','mesa-egl','mesa-gles','mesa-gbm'))
args=['apk','add','--no-network','/tmp/gta4l-upload/mesa-zink-kgsl-gta4l-26.0.8-r3.apk']+retain
trial=subprocess.run(args[:2]+['--simulate']+args[2:],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
print(trial.stdout,flush=True)
assert trial.returncode==0,'Offline dependency resolution failed; no packages changed'
assert not any(word in trial.stdout for word in ('Purging','Removing')),'Unexpected package removal; no packages changed'
for line in trial.stdout.splitlines():
    if 'Upgrading' in line or 'Downgrading' in line:
        assert 'mesa-zink-kgsl-gta4l (' in line,'Unexpected package change; no packages changed'
backup=Path('/root/gta4l-gpu-qc-backup')
backup.mkdir(mode=0o700,exist_ok=True)
(backup/'installed-before-zink-26.0.8-r3.json').write_text(json.dumps(before,indent=2)+'\n')
(backup/'world-before-zink-26.0.8-r3').write_bytes(Path('/etc/apk/world').read_bytes())
subprocess.run(args,check=True)
after=packages()
assert all(name=='mesa-zink-kgsl-gta4l' or after.get(name)==version for name,version in before.items()),'An existing system package changed unexpectedly'
assert after['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
print('Only the isolated Zink package was installed; existing package versions retained',flush=True)
PY
echo ZINK_ISOLATED_INSTALL_COMPLETE
