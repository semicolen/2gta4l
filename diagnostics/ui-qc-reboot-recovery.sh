#!/bin/sh
set -eu
for service in tinydm sddm gdm lightdm; do
    if [ -f "/etc/init.d/$service" ] && rc-service "$service" status >/dev/null 2>&1; then
        rc-service "$service" stop
    fi
done
python3 - <<'PY'
import ctypes
import os
import platform
assert os.geteuid() == 0 and platform.machine() == 'aarch64'
os.sync()
print('Entering OrangeFox for the next authorized desktop QC installation', flush=True)
libc = ctypes.CDLL(None, use_errno=True)
result = libc.syscall(ctypes.c_long(142), ctypes.c_ulong(0xfee1dead),
                      ctypes.c_ulong(672274793), ctypes.c_ulong(0xa1b2c3d4),
                      ctypes.c_char_p(b'recovery'))
if result != 0:
    raise OSError(ctypes.get_errno(), 'Recovery reboot failed')
PY
