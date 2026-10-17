#!/bin/sh
set -eu
date -u '+%Y-%m-%dT%H:%M:%SZ'
uname -a
cat /proc/uptime
python3 - <<'PY'
from pathlib import Path
import dbus
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    v=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if v.get('P','') in ('modemmanager','libmm-glib','gps-gta4l','gps-assistance-gta4l','gps-assistance-gta4l-openrc','camera-gta4l','camera-pipewire-gta4l','alsa-ucm-gta4l','alsa-ucm-gta4l-pulseaudio'):
        print('PACKAGE',v['P'],v['V'],flush=True)
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip() in ('gnome-shell','snapshot','wireplumber','ModemManager','pulseaudio','pipewire'):
            print('PROCESS',p.name,p.stat().st_uid,(p/'comm').read_text().strip(),flush=True)
    except (OSError,ProcessLookupError):pass
bus=dbus.SystemBus()
objects=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),
    'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
for path,interfaces in objects.items():
    loc=interfaces.get('org.freedesktop.ModemManager1.Modem.Location')
    if loc:print('LOCATION_CONFIGURATION',{k:loc[k] for k in ('SupportedAssistanceData','Enabled')},flush=True)
for path in (Path('/usr/libexec/gta4l-camera-pipewire-session'),Path('/etc/init.d/gta4l-gps-assistance')):
    print('PERSISTENT_HELPER',str(path),path.exists(),flush=True)
PY
