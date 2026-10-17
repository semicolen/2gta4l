#!/bin/sh
set -eu
printf 'USER_GROUPS\n'
id tablet
printf '\nPOLKIT_SERVICE\n'
rc-service polkit status
pid=$(pgrep -x polkitd | head -n 1)
ps -o pid,ppid,user,args | awk -v pid="$pid" 'NR == 1 || $1 == pid'
ls -ld "/proc/$pid/fdinfo"
printf '\nGRAPHICAL_SESSION\n'
python3 - <<'PY'
from pathlib import Path
import subprocess
session = next(p for p in Path('/proc').iterdir() if p.name.isdigit()
               and p.stat().st_uid == 10000 and (p / 'comm').read_text().strip() == 'kwin_wayland')
environment = dict(item.decode().split('=', 1) for item in (session / 'environ').read_bytes().split(b'\0')
                   if b'=' in item)
subprocess.run(['loginctl', 'show-session', environment['XDG_SESSION_ID'],
                '-p', 'User', '-p', 'Active', '-p', 'Remote', '-p', 'Seat', '-p', 'Type', '-p', 'Class'], check=True)
PY
printf '\nAUTHENTICATION_AGENTS\n'
pgrep -af 'polkit-kde|polkit.*agent|kded6|plasmashell' || true
printf '\nDEVICE_FAILURE_REASONS\n'
nmcli -f GENERAL.DEVICE,GENERAL.STATE,GENERAL.REASON device show wlan0
nmcli -f GENERAL.DEVICE,GENERAL.STATE,GENERAL.REASON device show swlan0
printf '\nLOG_TOOL_OPTIONS\n'
if command -v logbookctl >/dev/null 2>&1; then logbookctl --help; fi
if command -v logread >/dev/null 2>&1; then
    logread | grep -Ei 'NetworkManager|supplicant|polkit' | tail -n 140
fi
printf '\nPOLKIT_LOG\n'
tail -n 50 /var/log/gta4l/polkit.log
printf '\nNETWORK_AUTH_DIAGNOSTIC_END\n'
