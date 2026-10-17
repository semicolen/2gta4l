#!/bin/sh
# Preserve private session/network settings locally before the next clean UI QC.
set -eu
destination=/home/tablet/.cache/gta4l-ui-qc/plasma-state-before-next-ui.tar.gz
test -d /home/tablet/.config
test ! -e "$destination"
install -d -m 700 -o tablet -g tablet /home/tablet/.cache/gta4l-ui-qc
umask 077
python3 - <<'PY'
from pathlib import Path
import hashlib, os, tarfile
target = Path('/home/tablet/.cache/gta4l-ui-qc/plasma-state-before-next-ui.tar.gz')
names = ('home/tablet/.config', 'etc/NetworkManager/system-connections',
         'var/lib/bluetooth', 'etc/gta4l-ui-compat.json', 'etc/environment',
         'etc/profile.d/80-gta4l-rendering.sh', 'var/lib/sddm/state.conf',
         'usr/share/wayland-sessions/plasma.desktop',
         'usr/share/wayland-sessions/plasma-gta4l-software.desktop',
         'root/gta4l-gpu-qc-backup/session-trial-before')
with tarfile.open(target, 'x:gz') as archive:
    for name in names:
        source = Path('/') / name
        if source.exists(): archive.add(source, arcname=name)
assert 0 < target.stat().st_size < 32 * 1024 * 1024
target.chmod(0o600)
os.chown(target, 10000, 10000)
with target.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
print('PRIVATE_PLASMA_SETTINGS_BACKUP', target.stat().st_size, digest)
PY
