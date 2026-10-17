#!/bin/sh
# Coordinate-free camera and location-stack inventory.
set -eu
python3 - <<'PY'
from pathlib import Path
import dbus,os,subprocess
assert os.geteuid()==0
for block in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    item=dict(line.split(':',1) for line in block.splitlines() if ':' in line)
    name=item.get('P','')
    if name.startswith(('pipewire','wireplumber','gst-plugin-pipewire','libcamera','snapshot','aperture','libaperture','gnome-maps','geoclue','modemmanager','libqmi','camera-gta4l')):
        print('PACKAGE',name,item['V'],flush=True)
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit():continue
        name=(p/'comm').read_text().strip()
        if name in ('pipewire','wireplumber','snapshot','gnome-maps','geoclue','ModemManager','gnome-shell'):
            print('PROCESS',p.name,p.stat().st_uid,name,flush=True)
    except (FileNotFoundError,ProcessLookupError):pass
for p in sorted(Path('/sys/class/video4linux').glob('*')):
    print('VIDEO_NODE',p.name,(p/'name').read_text().strip(),flush=True)
bus=dbus.SystemBus()
objects=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),
                       'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
for path,interfaces in objects.items():
    loc=interfaces.get('org.freedesktop.ModemManager1.Modem.Location')
    if loc is None:continue
    print('MODEM_LOCATION_PROPERTIES',{str(k):v for k,v in loc.items() if str(k)!='Location'},flush=True)
    values=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1',path),
                          'org.freedesktop.ModemManager1.Modem.Location').GetLocation()
    for kind,value in values.items():
        if int(kind)==4:
            lines=str(value).splitlines()
            for line in lines:
                fields=line.split(',')
                if fields[0].endswith('GGA') and len(fields)>8:
                    print('GNSS_GGA','quality',fields[6],'satellites',fields[7],'hdop',fields[8],flush=True)
                if fields[0].endswith('RMC') and len(fields)>2:
                    print('GNSS_RMC','valid',fields[2]=='A',flush=True)
        elif int(kind)==2:
            print('GNSS_RAW','fields',sorted(map(str,value.keys())),
                  'coordinates_present',bool(value.get('latitude') is not None and value.get('longitude') is not None),flush=True)
        else:print('OTHER_LOCATION_SOURCE',int(kind),'present',bool(value),flush=True)
for path in (Path('/etc/geoclue/geoclue.conf'),Path('/etc/geoclue/conf.d/90-gta4l-gps.conf')):
    if path.exists():print('CONFIG',str(path),'\n'+path.read_text(),flush=True)
print('CAMERA_AND_LOCATION_INVENTORY_COMPLETE',flush=True)
PY
