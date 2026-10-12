#!/bin/sh
set -eu
eval "$(python3 - <<'PY'
import os, shlex
for item in os.listdir('/proc'):
    if not item.isdigit(): continue
    try:
        if open('/proc/'+item+'/comm').read().strip() != 'xfce4-session': continue
        env = open('/proc/'+item+'/environ', 'rb').read().split(b'\0')
    except (OSError, PermissionError): continue
    for entry in env:
        key, _, val = entry.partition(b'=')
        if key.decode() in ('DISPLAY','XAUTHORITY','DBUS_SESSION_BUS_ADDRESS','XDG_RUNTIME_DIR'):
            print('export '+key.decode()+'='+shlex.quote(val.decode()))
    break
PY
)"
echo '=== User audio server ==='
su tablet -s /bin/sh -c 'pactl info; pactl list short sinks; pactl list short sources; pactl list short cards; pactl list short modules'
echo '=== Amplifier startup log ==='
dmesg | grep -Ei 'fsm|fs1801|foursemi' | head -n 100
echo '=== ALSA ownership ==='
ls -l /dev/snd
echo AUDIO_PULSE_STATE_END
