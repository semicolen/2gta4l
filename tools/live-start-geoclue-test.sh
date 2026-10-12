#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import shlex
import subprocess
import signal
import os
agent_running=False
for entry in Path('/proc').iterdir():
    if not entry.name.isdigit(): continue
    try:
        exe=str((entry/'exe').resolve())
        if exe=='/usr/libexec/geoclue-2.0/demos/agent':
            agent_running=True
        if exe=='/usr/libexec/geoclue-2.0/demos/where-am-i':
            os.kill(int(entry.name),signal.SIGTERM)
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
pid=subprocess.check_output(['pidof','xfce4-session'],text=True).split()[0]
print('GeoClue agent already running before test='+str(agent_running))
env=[]
for item in Path('/proc/'+pid+'/environ').read_bytes().split(b'\0'):
    if item.startswith((b'DISPLAY=',b'DBUS_SESSION_BUS_ADDRESS=',b'XAUTHORITY=')):
        env.append(item.decode())
body='''umask 077
mkdir -p "$HOME/.cache/gta4l-gps"
chmod 700 "$HOME/.cache/gta4l-gps"
if [ "$GTA4L_AGENT_RUNNING" != 1 ]; then
    nohup /usr/libexec/geoclue-2.0/demos/agent >"$HOME/.cache/gta4l-gps/agent.log" 2>&1 </dev/null &
fi
sleep 1
nohup /usr/libexec/geoclue-2.0/demos/where-am-i --timeout=180 >"$HOME/.cache/gta4l-gps/where-am-i.log" 2>&1 </dev/null &
echo "GeoClue test client started as tablet"
'''
subprocess.run(['su','tablet','-s','/bin/sh','-c',shlex.join(['env',*env,'GTA4L_AGENT_RUNNING='+('1' if agent_running else '0'),'sh','-c',body])],check=True)
PY
sleep 2
printf '=== Location client state ===\n'
mmcli -m 0 --location-status
printf 'GEOCLUE_TEST_STARTED\n'
