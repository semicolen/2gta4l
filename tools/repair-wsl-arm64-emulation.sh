#!/bin/sh
set -eu
ROOT=/home/pmos/sm-t505-port
echo '=== Failed build summary ==='
tail -n 12 "$ROOT/work/log.txt"
echo '=== Native and chroot emulators ==='
file /usr/bin/qemu-aarch64 "$ROOT/work/chroot_native/usr/bin/qemu-aarch64"
ls -l "$ROOT/work/chroot_buildroot_aarch64/usr/bin/qemu-aarch64-static"
echo '=== Explicit static emulation ==='
"$ROOT/work/chroot_native/usr/bin/qemu-aarch64" -L "$ROOT/work/chroot_buildroot_aarch64" "$ROOT/work/chroot_buildroot_aarch64/bin/busybox" true
echo '=== Register the static host emulator with a fixed interpreter ==='
python3 - <<'PY'
from pathlib import Path
name = Path('/proc/sys/fs/binfmt_misc/qemu-aarch64')
if name.exists():
    name.write_text('-1\n')
magic = r'\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
mask = r'\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
interp = '/home/pmos/sm-t505-port/work/chroot_native/usr/bin/qemu-aarch64'
Path('/proc/sys/fs/binfmt_misc/register').write_text(':qemu-aarch64:M::'+magic+':'+mask+':'+interp+':F\n')
PY
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
chroot "$ROOT/work/chroot_buildroot_aarch64" /bin/sh -c 'echo ARM64_CHROOT_EXEC_VERIFIED'
