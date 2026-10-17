#!/bin/sh
# Compare the fresh automatic scale with the earlier verified native-pixel scale.
set -eu
python3 - <<'PY'
import os, subprocess, time
from pathlib import Path
assert os.getuid() == 10000
sessions = []
for process in Path('/proc').iterdir():
    try:
        if process.name.isdigit() and process.stat().st_uid == os.getuid() and (process/'comm').read_text().strip() == 'kwin_wayland':
            sessions.append(process)
    except (FileNotFoundError, ProcessLookupError): pass
assert len(sessions) == 1
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=')):
        key, value = entry.decode().split('=', 1)
        os.environ[key] = value
os.environ['QT_QPA_PLATFORM'] = 'wayland'
backup = Path.home()/'.cache/gta4l-ui-qc/before-native-scale'
backup.mkdir(parents=True, exist_ok=True, mode=0o700)
for name in ('kwinrc', 'kwinoutputconfig.json'):
    source = Path.home()/'.config'/name
    saved = backup/name
    if source.exists() and not saved.exists():
        saved.write_bytes(source.read_bytes()); saved.chmod(0o600)
print('BEFORE_SCALE_TEST', flush=True)
subprocess.run(['kscreen-doctor', '-o'], check=True, timeout=10)
subprocess.run(['kscreen-doctor', 'output.DSI-1.scale.1'], check=True, timeout=15)
time.sleep(2)
print('AFTER_SCALE_TEST', flush=True)
result = subprocess.check_output(['kscreen-doctor', '-o'], text=True, timeout=10)
print(result, flush=True)
assert any(line.strip() == 'Scale: 1' for line in result.splitlines())
print('NATIVE_PIXEL_SCALE_APPLIED', flush=True)
PY
