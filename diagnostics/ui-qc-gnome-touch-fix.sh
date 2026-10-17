#!/bin/sh
set -eu
python3 - <<'PY'
import json, os, subprocess
from pathlib import Path
assert os.geteuid() == 0
compat = Path('/etc/gta4l-ui-compat.json')
data = json.loads(compat.read_text())
assert data['ui'] in ('gnome', 'gnome-mobile')
source = Path('/tmp/gta4l-upload/99-gta4l-gnome-touch.rules')
lines = source.read_text().splitlines()
expected = 'SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="himax-touchscreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"'
assert [line for line in lines if line and not line.startswith('#')] == [expected]
target = Path('/etc/udev/rules.d/99-gta4l-gnome-touch.rules')
backup = Path('/var/lib/gta4l-ui-qc/before-gnome-touch')
backup.mkdir(parents=True, exist_ok=True, mode=0o700)
if target.exists() and not (backup/target.name).exists():
    (backup/target.name).write_bytes(target.read_bytes())
if not (backup/compat.name).exists(): (backup/compat.name).write_bytes(compat.read_bytes())
target.write_text('\n'.join(lines)+'\n'); target.chmod(0o644); os.chown(target,0,0)
subprocess.run(['udevadm','control','--reload-rules'], check=True, timeout=10)
found = []
for event in Path('/sys/class/input').glob('event*'):
    if (event/'device/name').read_text().strip() != 'himax-touchscreen': continue
    subprocess.run(['udevadm','trigger','--action=change',str(event)],check=True,timeout=10)
    subprocess.run(['udevadm','settle','--timeout=5'],check=True,timeout=8)
    properties = subprocess.check_output(['udevadm','info','--query=property','--path='+str(event)],text=True,timeout=10)
    assert 'LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1' in properties
    print(event.name, 'LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1', flush=True)
    found.append(event.name)
assert len(found)==1
data['gnome_touch_calibration']=True
compat.write_text(json.dumps(data,indent=2)+'\n')
os.sync()
print('GNOME_TOUCH_UDEV_RULE_VERIFIED; clean reboot required for compositor input',flush=True)
PY
