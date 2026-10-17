#!/bin/sh
set -u
echo '=== Service and D-Bus ownership ==='
rc-service iio-sensor-proxy status
python3 - <<'PY'
import dbus
from pathlib import Path
api=dbus.Interface(dbus.SystemBus().get_object('org.freedesktop.DBus','/org/freedesktop/DBus'),'org.freedesktop.DBus')
try:
    owner=api.GetNameOwner('net.hadess.SensorProxy')
    print('SENSOR_PROXY_OWNER',owner,'PID',int(api.GetConnectionUnixProcessID(owner)),flush=True)
except dbus.DBusException as error:print('SENSOR_PROXY_NAME',error.get_dbus_name(),flush=True)
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and (p/'comm').read_text().strip().startswith('iio-sensor'):
            print('PROXY_PROCESS',p.name,'wchan',(p/'wchan').read_text().strip(),flush=True)
    except (FileNotFoundError,ProcessLookupError):pass
PY
echo '=== Debug state changes ==='
grep -Ei 'claim|enabled|disabled|orientation|D-Bus|bus name|inhibit|error|failed|warning|polling' /var/log/gta4l/sensor-proxy-private/debug.log | tail -n 45
echo SENSOR_PROXY_DEBUG_SUMMARY_COMPLETE
