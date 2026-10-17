#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import subprocess
import os
import stat
interpreter = Path('/home/ark/sm-t505-port/work/chroot_native/usr/bin/qemu-aarch64')
assert interpreter.is_file() and interpreter.stat().st_mode & 0o111
assert 'static-pie linked' in subprocess.check_output(['file', str(interpreter)], text=True)
handler = Path('/proc/sys/fs/binfmt_misc/qemu-aarch64')
if handler.exists():
    handler.write_text('-1\n')
magic = r'\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
mask = r'\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
Path('/proc/sys/fs/binfmt_misc/register').write_text(
    ':qemu-aarch64:M::'+magic+':'+mask+':'+str(interpreter)+':OCF\n')
# WSL restarts can leave this existing build-root's device directory empty.
dev = Path('/home/ark/sm-t505-port/work/chroot_buildroot_aarch64/dev')
dev.mkdir(exist_ok=True)
for name, minor in [('null', 3), ('zero', 5), ('full', 7), ('random', 8), ('urandom', 9)]:
    path = dev / name
    if not path.exists():
        os.mknod(path, stat.S_IFCHR | 0o666, os.makedev(1, minor))
    assert stat.S_ISCHR(path.lstat().st_mode)
    path.chmod(0o666)
PY
chroot /home/ark/sm-t505-port/work/chroot_buildroot_aarch64 /bin/sh -c 'echo ARM64_CHROOT_EXEC_VERIFIED'
