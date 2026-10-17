#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import shutil,subprocess,os,re
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if fields.get('P') in ('libinput','libinput-libs','libinput-tools','glib','libevdev'):
        print('PACKAGE',fields.get('P'),fields.get('V'))
for name in ('LIBINPUT_QUIRKS_DIR','LIBINPUT_LOG_LEVEL'):
    print('ENV',name,os.environ.get(name))
for lib in Path('/usr/lib').glob('libinput.so.*'):
    if lib.is_symlink():continue
    data=lib.read_bytes()
    for raw in data.split(b'\0'):
        if b'local-overrides' in raw or (b'libinput' in raw and raw.startswith(b'/')):
            print('LIBINPUT_PATH',raw.decode(errors='replace'))
tool=shutil.which('libinput')
print('LIBINPUT_TOOL',tool)
if tool:subprocess.run([tool,'quirks','list','--verbose','/dev/input/event1'],timeout=15,check=False)
print('QUIRKS_OVERRIDE',Path('/etc/libinput/local-overrides.quirks').read_text())
PY
