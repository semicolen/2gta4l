#!/bin/sh
set -eu
printf '%s\n' \
 '13630eebb11d95f2a8009385e249c974ec45bcd12ec10be5379e2d874974bd63  /tmp/gta4l-upload/camera-gta4l-1.0-r4.apk' \
 '784f7f5555aad7a15c0df887e40385769ae73d306333cb3295f178bb1b4d9d0c  /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r4.apk' | sha256sum -c -
python3 - <<'PY'
import json,socket
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(5)
    peer.connect('/run/gta4l-camera/control.sock')
    peer.sendall(b'status\n')
    response=json.loads(peer.makefile('rb').readline())
    assert response['running'] is False and response['camera'] is None,response
print('Camera hardware is idle before package update',flush=True)
PY
# The exported image has no repository indexes. Explicitly retain the installed
# keyring stack so offline dependency resolution cannot purge weak dependencies.
simulation=$(apk add --simulate --no-network /tmp/gta4l-upload/camera-gta4l-1.0-r4.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r4.apk \
    gnome-keyring gnome-keyring-pam gnome-keyring-openrc gnome-keyring-lang gcr gcr-base gcr-lang 2>&1)
printf '%s\n' "$simulation"
if printf '%s\n' "$simulation" | grep -q 'Purging'; then
    printf 'Unexpected package removal; camera update stopped before mutation\n' >&2
    exit 1
fi
apk add --no-network /tmp/gta4l-upload/camera-gta4l-1.0-r4.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r4.apk \
    gnome-keyring gnome-keyring-pam gnome-keyring-openrc gnome-keyring-lang gcr gcr-base gcr-lang
python3 - <<'PY'
from pathlib import Path
records={}
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if 'P' in fields: records[fields['P']]=fields['V']
assert records['camera-gta4l']==records['camera-gta4l-openrc']=='1.0-r4'
assert 'wayland-utils' in records
print('Installed camera r4 and native output-query dependency',flush=True)
PY
