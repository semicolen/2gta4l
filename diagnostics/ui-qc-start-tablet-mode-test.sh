#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,subprocess,time
assert os.geteuid()==0
assert json.loads(Path('/etc/gta4l-ui-compat.json').read_text())['ui'] in ('gnome','gnome-mobile')
assert Path('/dev/uinput').exists()
for event in Path('/sys/class/input').glob('event*'):
    assert (event/'device/name').read_text().strip()!='gta4l-fixed-tablet-mode','Tablet-mode helper already running'
source=Path('/tmp/gta4l-upload/gta4l-tablet-mode-test').read_bytes()
assert hashlib.sha256(source).hexdigest()=='6c5302816d28427e8813578d5f183ff52745dd7bf698cfebaf73741ed179bf24'
folder=Path('/run/gta4l-ui-qc');folder.mkdir(mode=0o700,exist_ok=True)
assert folder.stat().st_uid==0
target=folder/'tablet-mode-helper';target.write_bytes(source);target.chmod(0o700)
with (folder/'tablet-mode.log').open('wb') as log:
    child=subprocess.Popen([str(target)],stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
(folder/'tablet-mode.pid').write_text(str(child.pid)+'\n')
time.sleep(3)
assert child.poll() is None,(folder/'tablet-mode.log').read_text()
found=[event for event in Path('/sys/class/input').glob('event*') if (event/'device/name').read_text().strip()=='gta4l-fixed-tablet-mode']
assert len(found)==1
print('TABLET_MODE_HELPER',child.pid,found[0].name,flush=True)
subprocess.run(['udevadm','info','--query=property','--path='+str(found[0])],check=True,timeout=10)
print((folder/'tablet-mode.log').read_text(),flush=True)
PY
