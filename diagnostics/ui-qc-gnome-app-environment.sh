#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,subprocess,shutil
assert os.getuid()==10000
names={'gnome-shell','dbus-daemon','gnome-session-b','nautilus','gnome-control-c','kgx','ptyxis','epiphany','gnome-calculat'}
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or p.stat().st_uid!=os.getuid():continue
        comm=(p/'comm').read_text().strip()
        if comm not in names:continue
        print('PROCESS',p.name,comm,flush=True)
        for entry in (p/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'LIBGL_',b'GALLIUM_',b'MESA_',b'GSK_',b'GDK_',b'GTA4L_',b'VK_',b'LD_LIBRARY_PATH=',b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=',b'WAYLAND_DISPLAY=')):
                print(entry.decode(errors='replace'),flush=True)
        if comm=='gnome-shell':
            for entry in (p/'environ').read_bytes().split(b'\0'):
                if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=',b'XDG_RUNTIME_DIR=')):
                    key,value=entry.decode().split('=',1);os.environ[key]=value
    except (FileNotFoundError,ProcessLookupError,PermissionError):pass
print('=== Launchable installed tools ===',flush=True)
for name in ('nautilus','gnome-control-center','gnome-calculator','kgx','ptyxis','epiphany','gtk4-demo','gtk4-widget-factory'):
    print(name,shutil.which(name),flush=True)
print('=== Application descriptor launch modes ===',flush=True)
for name in ('org.gnome.Nautilus.desktop','org.gnome.Settings.desktop','org.gnome.Calculator.desktop','org.gnome.Console.desktop'):
    path=Path('/usr/share/applications')/name
    if path.exists():
        print(name,flush=True)
        print('\n'.join(line for line in path.read_text().splitlines() if line.startswith(('Exec=','DBusActivatable=','TryExec='))),flush=True)
print('=== GTK versions ===',flush=True)
for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    fields=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
    if fields.get('P') in ('gtk4.0','gtk+3.0','libadwaita','gjs','dbus'):print(fields['P'],fields['V'],flush=True)
PY
