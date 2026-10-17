#!/bin/sh
# Report reception quality without recording coordinates or raw NMEA.
set -eu
python3 - <<'PY'
import dbus,time
bus=dbus.SystemBus()
objects=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),
    'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
path=next(p for p,v in objects.items() if 'org.freedesktop.ModemManager1.Modem.Location' in v)
obj=bus.get_object('org.freedesktop.ModemManager1',path)
props=dbus.Interface(obj,'org.freedesktop.DBus.Properties')
loc=dbus.Interface(obj,'org.freedesktop.ModemManager1.Modem.Location')
start=time.monotonic()
for sample in range(9):
    status=props.GetAll('org.freedesktop.ModemManager1.Modem.Location')
    summary={'elapsed_s':round(time.monotonic()-start,1),'enabled_sources':int(status['Enabled'])}
    values=loc.GetLocation()
    for kind,value in values.items():
        if int(kind)!=4:continue
        for line in str(value).splitlines():
            f=line.split(',')
            if f[0].endswith('GGA') and len(f)>8:
                summary.update(quality=f[6],satellites_used=f[7],hdop=f[8])
            elif f[0].endswith('RMC') and len(f)>2:summary['valid']=f[2]=='A'
            elif f[0].endswith('GSV') and len(f)>3:summary['satellites_visible']=f[3]
    print(summary,flush=True)
    if sample<8:time.sleep(5)
print('COORDINATE_FREE_GNSS_SAMPLE_COMPLETE',flush=True)
PY
