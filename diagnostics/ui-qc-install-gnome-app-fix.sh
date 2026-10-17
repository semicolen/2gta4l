#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,re,subprocess
assert os.geteuid()==0
compat=Path('/etc/gta4l-ui-compat.json')
receipt=json.loads(compat.read_text())
assert receipt['ui']=='gnome'
uploaded=Path('/tmp/gta4l-upload/gta4l-gnome-session')
assert hashlib.sha256(uploaded.read_bytes()).hexdigest()=='1310ca486f2072a2e1a974cd2e42902a146f1bfbfe1d24c1868e0298c5f404cf'
target=Path('/usr/bin/gta4l-gnome-session')
assert not target.exists()
session=Path('/usr/share/wayland-sessions/gnome.desktop')
fallback=session.with_name('gnome-gta4l-software.desktop')
original=session.read_text();oldfallback=fallback.read_text()
assert re.search(r'^Exec=/usr/bin/gta4l-zink-run /usr/bin/gnome-session\s*$',original,re.M)
assert re.search(r'^Exec=/usr/bin/gnome-session\s*$',oldfallback,re.M)
backup=Path('/var/lib/gta4l-ui-qc/gnome-app-launch-before')
backup.mkdir(mode=0o700,parents=True,exist_ok=False)
for path in (session,fallback,compat):(backup/path.name).write_bytes(path.read_bytes())
target.write_bytes(uploaded.read_bytes());target.chmod(0o755);os.chown(target,0,0)
subprocess.run(['/bin/sh','-n',str(target)],check=True)
session.write_text(re.sub(r'^Exec=/usr/bin/gta4l-zink-run /usr/bin/gnome-session\s*$',
    'Exec=/usr/bin/gta4l-zink-run /usr/bin/gta4l-gnome-session',original,flags=re.M))
fallback.write_text(re.sub(r'^Exec=/usr/bin/gnome-session\s*$',
    'Exec=/usr/bin/gta4l-gnome-session',oldfallback,flags=re.M))
receipt['gnome_gtk_opengl']=True;receipt['revision']=6
compat.write_text(json.dumps(receipt,indent=2)+'\n')
rollback=backup/'rollback.sh'
rollback.write_text('''#!/bin/sh
set -eu
base=/var/lib/gta4l-ui-qc/gnome-app-launch-before
install -m644 "$base/gnome.desktop" /usr/share/wayland-sessions/gnome.desktop
install -m644 "$base/gnome-gta4l-software.desktop" /usr/share/wayland-sessions/gnome-gta4l-software.desktop
install -m644 "$base/gta4l-ui-compat.json" /etc/gta4l-ui-compat.json
rm -f /usr/bin/gta4l-gnome-session
sync
''');rollback.chmod(0o700)
subprocess.run(['/bin/sh','-n',str(rollback)],check=True)
os.sync()
print('GNOME_GTK_OPENGL_SESSION_FIX_INSTALLED_WITH_ROLLBACK; takes effect at next login',flush=True)
PY
