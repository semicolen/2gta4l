#!/bin/sh
set -eu
python3 - <<'PY'
import os,re,subprocess
from pathlib import Path
assert os.getuid()==0
records={}
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if 'P' in fields:records[fields['P']]=fields['V']
assert records['mesa-zink-kgsl-gta4l']=='26.0.8-r3'
backup=Path('/root/gta4l-gpu-qc-backup/session-trial-before')
assert not backup.exists(),'Session trial already prepared; inspect existing backup first'
session=Path('/usr/share/wayland-sessions/plasma.desktop')
fallback=Path('/usr/share/wayland-sessions/plasma-gta4l-software.desktop')
profile=Path('/etc/profile.d/80-gta4l-rendering.sh')
userenv=Path('/home/tablet/.config/plasma-workspace/env/80-gta4l-zink.sh')
assert not fallback.exists() and not userenv.exists(),'Would overwrite an existing session customization'
oldsession=session.read_text()
oldprofile=profile.read_text()
assert 'Exec=/usr/lib/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland' in oldsession
assert 'LIBGL_ALWAYS_SOFTWARE=1' in oldprofile and 'GALLIUM_DRIVER=llvmpipe' in oldprofile
backup.mkdir(parents=True,mode=0o700)
(backup/'plasma.desktop').write_bytes(session.read_bytes())
(backup/'80-gta4l-rendering.sh').write_bytes(profile.read_bytes())
fallback.write_text(re.sub(r'^Name=.*$', 'Name=Plasma (Software fallback)',oldsession,flags=re.M))
session.write_text(oldsession.replace('Exec=/usr/lib/libexec/plasma-dbus-run-session-if-needed',
                                     'Exec=/usr/bin/gta4l-zink-run /usr/lib/libexec/plasma-dbus-run-session-if-needed'))
profile.write_text('# Respect the explicit Adreno session selected by gta4l-zink-run.\n'
                  'if [ "${GTA4L_ZINK_KGSL:-0}" != 1 ]; then\n'+oldprofile+'\nfi\n')
userenv.parent.mkdir(parents=True,exist_ok=True)
userenv.write_text('''#!/bin/sh
# Apply only to the explicitly selected Adreno session; preserve the fallback.
if [ "${GTA4L_ZINK_KGSL:-0}" = 1 ]; then
    unset LIBGL_ALWAYS_SOFTWARE D3D_ALWAYS_SOFTWARE QT_QUICK_BACKEND
    export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
    export GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink GTA4L_ZINK_KGSL=1
    export LIBGL_KOPPER_DISABLE=true
    export LIBGL_DRIVERS_PATH=/usr/lib/gta4l-zink/lib/dri
    export LD_LIBRARY_PATH=/usr/lib/gta4l-zink/lib
fi
''')
userenv.chmod(0o700)
os.chown(userenv,10000,10000)
for directory in (userenv.parent,userenv.parent.parent):
    os.chown(directory,10000,10000)
rollback=backup/'rollback.sh'
rollback.write_text('''#!/bin/sh
set -eu
test "$(id -u)" = 0
install -m644 /root/gta4l-gpu-qc-backup/session-trial-before/plasma.desktop /usr/share/wayland-sessions/plasma.desktop
install -m644 /root/gta4l-gpu-qc-backup/session-trial-before/80-gta4l-rendering.sh /etc/profile.d/80-gta4l-rendering.sh
rm -f /usr/share/wayland-sessions/plasma-gta4l-software.desktop /home/tablet/.config/plasma-workspace/env/80-gta4l-zink.sh
sync
echo PLASMA_SOFTWARE_SESSION_RESTORED
''')
rollback.chmod(0o700)
for path in (profile,userenv,rollback):subprocess.run(['/bin/sh','-n',str(path)],check=True)
subprocess.run(['sync'],check=True)
print('Prepared next-login Adreno Plasma session, software fallback and exact rollback script',flush=True)
print('Current desktop and SDDM greeter are unchanged until the clean reboot',flush=True)
PY
echo PLASMA_ZINK_SESSION_PREPARED
