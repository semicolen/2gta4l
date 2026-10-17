#!/bin/sh
set -eu
python3 - <<'PY'
import dbus,time
bus=dbus.SystemBus()
manager=dbus.Interface(bus.get_object('org.freedesktop.ModemManager1','/org/freedesktop/ModemManager1'),
    'org.freedesktop.DBus.ObjectManager')
for attempt in range(31):
    objects=manager.GetManagedObjects()
    if any('org.freedesktop.ModemManager1.Modem.Location' in v for v in objects.values()):break
    time.sleep(1)
else:raise RuntimeError('Modem location interface did not finish initialization')
for path,interfaces in objects.items():
    loc=interfaces.get('org.freedesktop.ModemManager1.Modem.Location')
    if loc is None:continue
    print('ASSISTANCE_PROPERTIES',{str(k):loc[k] for k in
        ('SupportedAssistanceData','AssistanceDataServers','SuplServer','Enabled','GpsRefreshRate')},flush=True)
PY
timeout 15 qmicli -d qrtr://0 --loc-get-predicted-orbits-data-validity || true
echo COORDINATE_FREE_ASSISTANCE_STATE_COMPLETE
