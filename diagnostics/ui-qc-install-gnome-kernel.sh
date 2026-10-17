#!/bin/sh
# Install matching files without invoking a boot-image flashing hook.
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess
assert os.geteuid()==0
assert '#9-postmarketOS' in subprocess.check_output(['uname','-v'],text=True)
package=Path('/tmp/gta4l-upload/linux-samsung-gta4l-4.19.300-r9.apk')
assert hashlib.sha256(package.read_bytes()).hexdigest()=='ab118f132413dce7cfdf2231f354e59ac2486fa1186202b3eabdb3885b4c34e2'
expected='4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663'
def boot_hash():
    with open('/dev/mmcblk0p69','rb') as source:return hashlib.sha256(source.read(28938256)).hexdigest()
assert boot_hash()==expected
assert int(Path('/sys/class/power_supply/battery/capacity').read_text())>=25
assert 'Exec=/usr/bin/gnome-session' in Path('/usr/share/wayland-sessions/gnome.desktop').read_text()
def versions():
    result={}
    for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        fields=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
        if 'P' in fields:result[fields['P']]=fields['V']
    return result
before=versions()
assert before['linux-samsung-gta4l']=='4.19.300-r8'
command=['apk','--no-network','--no-interactive','--no-scripts','add',str(package)]
trial=subprocess.run(command[:1]+['--simulate']+command[1:],capture_output=True,text=True,check=True)
print(trial.stdout,flush=True)
assert 'Purging' not in trial.stdout
backup=Path('/root/gta4l-ui-qc/kernel10-before')
backup.mkdir(mode=0o700,parents=True,exist_ok=False)
(backup/'versions.json').write_text(json.dumps(before,indent=2)+'\n')
subprocess.run(command,check=True)
after=versions()
assert after.pop('linux-samsung-gta4l')=='4.19.300-r9'
before.pop('linux-samsung-gta4l')
assert before==after,'Unrelated package versions changed'
assert boot_hash()==expected,'Boot hook unexpectedly changed physical boot'
os.sync()
print('KERNEL10_FILES_INSTALLED; physical boot remains verified kernel9; all other package versions unchanged',flush=True)
PY
