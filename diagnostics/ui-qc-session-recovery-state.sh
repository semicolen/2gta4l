#!/bin/sh
# Read-only snapshot of all compositor sessions after a display-manager restart.
set -u
uptime
free -m
rc-service tinydm status
loginctl list-sessions
ps -o pid,ppid,user,args | grep -E 'kwin|plasma|tinydm|sddm|login|maliit|polkit' | grep -v grep
python3 - <<'PY'
from pathlib import Path
import subprocess
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit() or (p/'comm').read_text().strip() != 'kwin_wayland':
            continue
        env = dict(s.decode().split('=', 1) for s in (p/'environ').read_bytes().split(b'\0') if b'=' in s)
        sid = env.get('XDG_SESSION_ID')
        print('COMPOSITOR', p.name, 'UID', p.stat().st_uid, 'SESSION', sid, flush=True)
        subprocess.run(['loginctl', 'show-session', sid, '-p', 'User', '-p', 'Active', '-p', 'Remote', '-p', 'State'], timeout=5)
    except (FileNotFoundError, ProcessLookupError):
        continue
PY
printf '\nRECENT_KERNEL_ERRORS\n'
dmesg | grep -Ei 'out of memory|killed process|segfault|panic|drm|dsi|sde' | tail -n 45
printf '\nDISPLAY_MANAGER_LOGS\n'
find /var/log/tinydm /home/tablet/.local/state/tinydm -maxdepth 2 -type f 2>/dev/null | while read -r path; do
    printf '\n%s\n' "$path"
    tail -n 35 "$path"
done
