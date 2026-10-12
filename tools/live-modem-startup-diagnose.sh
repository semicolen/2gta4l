#!/bin/sh
set -u
rc-service modemmanager status
mmcli --version
mmcli -L
printf '=== Recent modem process messages ===\n'
if [ -f /var/log/messages ]; then
    grep -E 'ModemManager|modemmanager|qrtr' /var/log/messages | tail -n 100
fi
printf '=== Modem process arguments ===\n'
python3 - <<'PY'
from pathlib import Path
for p in Path('/proc').iterdir():
    if not p.name.isdigit(): continue
    try:
        if str((p/'exe').resolve())=='/usr/sbin/ModemManager':
            print(p.name,(p/'cmdline').read_bytes().replace(b'\0',b' ').decode())
    except (FileNotFoundError,PermissionError,ProcessLookupError): pass
PY
qmicli -d qrtr://0 --loc-get-operation-mode
printf 'MODEM_STARTUP_DIAGNOSE_END\n'
