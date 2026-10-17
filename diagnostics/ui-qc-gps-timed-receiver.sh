#!/bin/sh
# Bounded receiver test; never print coordinates and restore the source mask.
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
initial=props.GetAll('org.freedesktop.ModemManager1.Modem.Location')
old=int(initial['Enabled']); signals=bool(initial['SignalsLocation'])
start=time.monotonic(); first=None
try:
    loc.Setup(dbus.UInt32(old|4),signals,timeout=25)
    print('RECEIVER_REQUEST_READY_SECONDS',round(time.monotonic()-start,2),flush=True)
    for sample in range(61):
        result={}
        for kind,value in loc.GetLocation().items():
            if int(kind)!=4:continue
            for line in str(value).splitlines():
                f=line.split(',')
                if f[0].endswith('GGA') and len(f)>8:
                    result.update(quality=f[6],satellites_used=f[7],hdop=f[8])
                elif f[0].endswith('RMC') and len(f)>2:result['valid']=f[2]=='A'
                elif f[0].endswith('GSV') and len(f)>3:result['satellites_visible']=f[3]
        elapsed=round(time.monotonic()-start,2)
        if first is None and (result.get('valid') or result.get('quality') not in (None,'','0')):
            first=elapsed;print('FIRST_VALID_FIX_SECONDS',first,flush=True)
        if sample%5==0:print({'elapsed_s':elapsed,**result},flush=True)
        if sample<60:time.sleep(1)
finally:
    current=props.GetAll('org.freedesktop.ModemManager1.Modem.Location')
    # Do not remove sources added by another client during the diagnostic.
    if int(current['Enabled'])==old|4 and bool(current['SignalsLocation'])==signals:
        loc.Setup(dbus.UInt32(old),signals,timeout=25)
        print('PREVIOUS_SOURCE_MASK_RESTORED',old,flush=True)
    else:print('CLIENT_CHANGED_CONFIGURATION_PRESERVED',flush=True)
print('TIMED_RECEIVER_COMPLETE','valid_fix_observed',first is not None,flush=True)
PY
