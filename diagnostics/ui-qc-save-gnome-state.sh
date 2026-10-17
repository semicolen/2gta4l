#!/bin/sh
# Preserve private GNOME settings and test photos before clean-installer QC.
set -eu
umask 077
python3 - <<'PY'
from pathlib import Path
import hashlib,os,tarfile
assert os.geteuid()==0
folder=Path('/home/tablet/.cache/gta4l-ui-qc')
folder.mkdir(mode=0o700,parents=True,exist_ok=True)
os.chown(folder,10000,10000)
target=folder/'gnome-runtime-state-before-r13.tar.gz'
assert not target.exists()
names=('home/tablet/.config','home/tablet/Pictures','home/tablet/.local/share/keyrings',
       'etc/NetworkManager/system-connections','var/lib/bluetooth','etc/gta4l-ui-compat.json',
       'etc/environment','etc/profile.d/80-gta4l-rendering.sh',
       'usr/share/wayland-sessions/gnome.desktop','usr/share/wayland-sessions/gnome-gta4l-software.desktop',
       'etc/udev/rules.d/99-gta4l-gnome-touch.rules','usr/bin/gta4l-gnome-session',
       'var/lib/gta4l-ui-qc/gnome-app-launch-before',
       'root/gta4l-gpu-qc-backup/gnome-session-before')
sources=[Path('/')/name for name in names if (Path('/')/name).exists()]
size=sum(p.stat().st_size for root in sources for p in ([root] if root.is_file() else root.rglob('*')) if p.is_file() and not p.is_symlink())
assert size<30*1024*1024,'Preserve a larger backup before proceeding; no files removed'
with tarfile.open(target,'x:gz') as archive:
    for source in sources:archive.add(source,arcname=source.as_posix().lstrip('/'))
assert 0<target.stat().st_size<32*1024*1024
target.chmod(0o600);os.chown(target,10000,10000)
with target.open('rb') as source:digest=hashlib.file_digest(source,'sha256').hexdigest()
print('PRIVATE_GNOME_STATE_BACKUP',target.stat().st_size,digest,flush=True)
PY
