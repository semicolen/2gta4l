#!/bin/sh
set -u
echo '=== Local quirks file ==='
ls -l /etc/libinput/local-overrides.quirks 2>/dev/null || true
cat /etc/libinput/local-overrides.quirks 2>/dev/null || true
echo '=== All device capabilities ==='
/usr/sbin/libinput list-devices
echo '=== Sensor claim callers ==='
python3 - <<'PY'
import dbus
bus=dbus.SystemBus()
obj=bus.get_object('org.freedesktop.DBus','/org/freedesktop/DBus')
api=dbus.Interface(obj,'org.freedesktop.DBus')
for name in api.ListNames():
    if not name.startswith(':'):continue
    try:
        pid=int(api.GetConnectionUnixProcessID(name))
        from pathlib import Path
        comm=Path('/proc',str(pid),'comm').read_text().strip()
        if comm in ('gnome-shell','iio-sensor-proxy'):print('BUS_PEER',str(name),'PID',pid,'COMM',comm,flush=True)
    except (dbus.DBusException,FileNotFoundError,ProcessLookupError):pass
PY
