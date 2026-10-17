#!/bin/sh
set -eu
printf '%s\n' \
 '8be8ddbb099bb22e78f584fed328597dda9e64fcd5da16b0f363df8c3d3c4e34  /tmp/gta4l-upload/camera-gta4l-1.0-r3.apk' \
 '6707427bdc29046665978bf94ed43b33d0ed3ea5577b372a48d3f5a44d5b9b8a  /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r3.apk' | sha256sum -c -
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
simulation=$(apk add --simulate --no-network /tmp/gta4l-upload/camera-gta4l-1.0-r3.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r3.apk \
    gnome-keyring gnome-keyring-pam gnome-keyring-openrc gnome-keyring-lang gcr gcr-base gcr-lang 2>&1)
printf '%s\n' "$simulation"
if printf '%s\n' "$simulation" | grep -q 'Purging'; then
    printf 'Unexpected package removal; camera update stopped before mutation\n' >&2
    exit 1
fi
apk add --no-network /tmp/gta4l-upload/camera-gta4l-1.0-r3.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r3.apk \
    gnome-keyring gnome-keyring-pam gnome-keyring-openrc gnome-keyring-lang gcr gcr-base gcr-lang
python3 - <<'PY'
from pathlib import Path
records={}
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if 'P' in fields: records[fields['P']]=fields['V']
assert records['camera-gta4l']==records['camera-gta4l-openrc']=='1.0-r3'
assert 'wayland-utils' in records
print('Installed camera r3 and native output-query dependency',flush=True)
PY
