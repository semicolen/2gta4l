#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import ctypes as c,os,tempfile,errno,platform
from gi.repository import Gio
assert os.getuid()==10000 and platform.machine()=='aarch64'
libc=c.CDLL(None,use_errno=True)
libc.faccessat.argtypes=[c.c_int,c.c_char_p,c.c_int,c.c_int]
libc.faccessat.restype=c.c_int
with tempfile.TemporaryDirectory(prefix='gta4l-file-check-') as folder:
    path=Path(folder)/'present';path.write_text('temporary compatibility check\n')
    missing=Path(folder)/'absent'
    print('POSIX_PRESENT',path.exists(),'GIO_PRESENT',Gio.File.new_for_path(str(path)).query_exists(None),flush=True)
    print('POSIX_ABSENT',missing.exists(),'GIO_ABSENT',Gio.File.new_for_path(str(missing)).query_exists(None),flush=True)
    for flags in (0,0x100,0x200,0x300):
        c.set_errno(0);result=libc.faccessat(-100,os.fsencode(path),os.F_OK,flags);error=c.get_errno()
        print('LIBC_FACCESSAT',hex(flags),'result',result,'errno',error,errno.errorcode.get(error),flush=True)
    c.set_errno(0)
    result=libc.syscall(c.c_long(439),c.c_int(-100),c.c_char_p(os.fsencode(path)),c.c_int(os.F_OK),c.c_int(0x100))
    error=c.get_errno()
    print('KERNEL_FACCESSAT2','result',result,'errno',error,errno.errorcode.get(error),flush=True)
print('FILE_EXISTENCE_COMPATIBILITY_CHECK_COMPLETE',flush=True)
PY
