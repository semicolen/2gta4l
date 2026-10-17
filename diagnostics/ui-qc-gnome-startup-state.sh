#!/bin/sh
# Bounded, read-only GDM/GNOME startup evidence over the USB connection.
set -u
uname -r
cat /proc/sys/kernel/random/boot_id
free -m
rc-service gdm status
loginctl list-sessions
python3 - <<'PY'
from pathlib import Path
names = {'gdm', 'gdm-wayland-ses', 'gdm-session-wor', 'gnome-shell',
         'gnome-session', 'gnome-session-b', 'gnome-session-c', 'Xwayland'}
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or (p/'comm').read_text().strip() not in names: continue
        print('GNOME_PROCESS', p.name, 'uid', p.stat().st_uid,
              (p/'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace'))
        for entry in (p/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'LIBGL_', b'GALLIUM_', b'MESA_', b'GTA4L_', b'VK_DRIVER_',
                                 b'WAYLAND_DISPLAY=', b'DISPLAY=', b'XDG_SESSION_TYPE=')):
                print(entry.decode(errors='replace'))
    except (FileNotFoundError, ProcessLookupError, PermissionError): pass
system_logs = (Path('/var/log/messages'), Path('/var/log/rc.log'))
paths = list(system_logs)
paths += [Path('/home/tablet')/name for name in ('.cache/gdm/session.log',
          '.local/share/gdm/session.log', '.local/state/gdm/session.log', '.xsession-errors')]
directory = Path('/var/log/gdm')
if directory.is_dir(): paths.extend(sorted(p for p in directory.iterdir() if p.is_file())[:8])
for path in paths:
    if not path.is_file(): continue
    with path.open('rb') as stream:
        stream.seek(max(0, path.stat().st_size-65536))
        lines = stream.read(65536).decode(errors='replace').splitlines()
    if path in system_logs:
        lines = [line for line in lines if any(word in line.lower() for word in
                 ('gdm', 'gnome', 'mutter', 'egl', 'gbm', 'segfault', 'out of memory', 'killed process'))]
    print('LOG', path)
    print('\n'.join(lines[-90:]))
PY
printf '\nRECENT_DISPLAY_KERNEL_MESSAGES\n'
dmesg | grep -Ei 'drm|dsi|sde|kgsl|gpu fault|out of memory|killed process|segfault|panic' | tail -n 45
echo GNOME_STARTUP_SNAPSHOT_COMPLETE
