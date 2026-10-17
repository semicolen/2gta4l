#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,re
assert os.geteuid()==0
assert json.loads(Path('/etc/gta4l-ui-compat.json').read_text())['ui'] in ('gnome','gnome-mobile')
source=Path('/tmp/gta4l-upload/gnome-himax.quirks').read_text()
assert '[Galaxy Tab A7 Himax touchscreen]\nMatchName=himax-touchscreen\n' in source
line=next(line for line in source.splitlines() if line.startswith('AttrEventCode='))
assert line=='AttrEventCode=-BTN_LEFT;-BTN_RIGHT;-BTN_MIDDLE;-BTN_SIDE;','Only the Himax mouse-button filter is allowed'
target=Path('/etc/libinput/local-overrides.quirks')
target.parent.mkdir(mode=0o755,exist_ok=True)
backup=Path('/var/lib/gta4l-ui-qc/before-gnome-touch/local-overrides.quirks')
old=target.read_text() if target.exists() else ''
if target.exists() and not backup.exists():backup.write_bytes(target.read_bytes())
old=re.sub(r'\[Galaxy Tab A7 Himax touchscreen\]\n.*?(?=\n\[|\Z)','',old,flags=re.S)
target.write_text(old.rstrip()+'\n\n'+source.rstrip()+'\n');target.chmod(0o644)
os.sync()
print('GNOME_HIMAX_QUIRK_STAGED; validate a new libinput context before restarting desktop',flush=True)
PY
