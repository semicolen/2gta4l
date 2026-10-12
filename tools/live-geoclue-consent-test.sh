#!/bin/sh
set -eu
umask 077
install -d -m 700 -o geoclue -g geoclue /run/gta4l-gps-agent-check
cat > /run/gta4l-gps-agent-check/agent-check.py <<'PY'
from pathlib import Path
import dbus
import json
import sys

out=Path('/run/gta4l-gps-agent-check/result.json')
bus=dbus.SystemBus()
agent=dbus.Interface(bus.get_object(sys.argv[1],'/org/freedesktop/GeoClue2/Agent',introspect=False),'org.freedesktop.GeoClue2.Agent')
print('Requesting actual GeoClue consent notification',flush=True)
allowed,accuracy=agent.AuthorizeApp('geoclue-where-am-i',dbus.UInt32(8),signature='su',timeout=120)
out.write_text(json.dumps({'authorized':bool(allowed),'accuracy_level':int(accuracy)})+'\n')
print('Location consent result received',flush=True)
PY
chown geoclue:geoclue /run/gta4l-gps-agent-check/agent-check.py
python3 - <<'PY'
from pathlib import Path
import dbus
import shlex
import subprocess
bus=dbus.SystemBus()
daemon=dbus.Interface(bus.get_object('org.freedesktop.DBus','/org/freedesktop/DBus'),'org.freedesktop.DBus')
for name in daemon.ListNames():
    if not str(name).startswith(':'): continue
    try:
        pid=int(daemon.GetConnectionUnixProcessID(name))
        if str(Path('/proc/'+str(pid)+'/exe').resolve())!='/usr/libexec/geoclue-2.0/demos/agent': continue
        command='nohup python3 /run/gta4l-gps-agent-check/agent-check.py '+shlex.quote(str(name))+' > /run/gta4l-gps-agent-check/result.log 2>&1 </dev/null &'
        subprocess.run(['su','geoclue','-s','/bin/sh','-c',command],check=True)
        break
    except (dbus.DBusException,FileNotFoundError,PermissionError): pass
else: raise SystemExit('No GeoClue agent found')
PY
sleep 2
cat /run/gta4l-gps-agent-check/result.log
printf 'GEOCLUE_CONSENT_TEST_STARTED\n'
