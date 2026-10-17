#!/bin/sh
# Prepare a separate accelerated user session; retain the software GDM greeter.
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,re,subprocess
assert os.geteuid()==0
assert json.loads(Path('/etc/gta4l-ui-compat.json').read_text())['ui']=='gnome'
assert Path('/usr/lib/gta4l-zink/lib/libgallium-26.0.8.so').is_file()
session=Path('/usr/share/wayland-sessions/gnome.desktop')
profile=Path('/etc/profile.d/80-gta4l-rendering.sh')
fallback=session.with_name('gnome-gta4l-software.desktop')
backup=Path('/root/gta4l-gpu-qc-backup/gnome-session-before')
assert not fallback.exists()
original=session.read_text()
assert re.search(r'^Exec=/usr/bin/gnome-session\s*$',original,re.M)
oldprofile=profile.read_text()
assert 'LIBGL_ALWAYS_SOFTWARE=1' in oldprofile and 'GALLIUM_DRIVER=llvmpipe' in oldprofile
# Reuse only an exact rollback of this trial; preserve the original backup.
if backup.exists():
    assert (backup/'gnome.desktop').read_bytes()==session.read_bytes()
    assert (backup/'80-gta4l-rendering.sh').read_bytes()==profile.read_bytes()
else:
    backup.mkdir(mode=0o700)
    (backup/'gnome.desktop').write_bytes(session.read_bytes())
    (backup/'80-gta4l-rendering.sh').write_bytes(profile.read_bytes())
# Require a real hardware shader/readback pass before changing next-login config.
subprocess.run(['su','tablet','-s','/bin/sh','-c',
    'XDG_RUNTIME_DIR=/run/user/10000 timeout 25 gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware'],check=True,timeout=30)
fallback.write_text(re.sub(r'^(Name(?:\[[^\]]+\])?)=.*$',r'\1=GNOME (Software fallback)',original,flags=re.M))
session.write_text(re.sub(r'^Exec=/usr/bin/gnome-session\s*$',
                         'Exec=/usr/bin/gta4l-zink-run /usr/bin/gnome-session',original,flags=re.M))
profile.write_text('# Respect the explicitly selected Adreno desktop session.\n'
                  'if [ "${GTA4L_ZINK_KGSL:-0}" != 1 ]; then\n'+oldprofile+'\nfi\n')
rollback=backup/'rollback.sh'
rollback.write_text('''#!/bin/sh
set -eu
install -m644 /root/gta4l-gpu-qc-backup/gnome-session-before/gnome.desktop /usr/share/wayland-sessions/gnome.desktop
install -m644 /root/gta4l-gpu-qc-backup/gnome-session-before/80-gta4l-rendering.sh /etc/profile.d/80-gta4l-rendering.sh
rm -f /usr/share/wayland-sessions/gnome-gta4l-software.desktop
sync
echo GNOME_SOFTWARE_SESSION_RESTORED
''')
rollback.chmod(0o700)
for path in (profile,rollback):subprocess.run(['/bin/sh','-n',str(path)],check=True)
os.sync()
print('GNOME_ADRENO_NEXT_LOGIN_PREPARED; software greeter, fallback and rollback retained',flush=True)
PY
