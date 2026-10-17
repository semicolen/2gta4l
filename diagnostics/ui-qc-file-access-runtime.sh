#!/bin/sh
set -eu
grep -q '#11-postmarketOS' /proc/version
python3 - <<'PY'
from pathlib import Path
import ctypes as c, errno, os, tempfile
from gi.repository import Gio
assert os.geteuid() == 0 and os.uname().machine == 'aarch64'
libc = c.CDLL(None, use_errno=True)
libc.syscall.restype = c.c_long
libc.faccessat.argtypes = [c.c_int, c.c_char_p, c.c_int, c.c_int]
libc.faccessat.restype = c.c_int
checks = 0

def check(label, path, mode=0, flags=0, fd=-100, expected=0, legacy=False):
    global checks
    c.set_errno(0)
    if legacy:
        result = libc.syscall(c.c_long(48), c.c_int(fd), c.c_char_p(os.fsencode(path)), c.c_int(mode))
    else:
        result = libc.syscall(c.c_long(439), c.c_int(fd), c.c_char_p(os.fsencode(path)), c.c_int(mode), c.c_int(flags))
    actual = c.get_errno() if result == -1 else 0
    assert result in (0, -1) and actual == expected, (label, result, actual, expected)
    checks += 1
    print('PASS', label, errno.errorcode.get(actual, 'OK'), flush=True)

with tempfile.TemporaryDirectory(prefix='gta4l-faccessat2-') as folder:
    folder = Path(folder); folder.chmod(0o755)
    present = folder/'present'; present.write_text('private API regression fixture\n')
    present.chmod(0o600); os.chown(present, 10000, 10000)
    missing = folder/'missing'
    link = folder/'link'; link.symlink_to(present.name)
    dangling = folder/'dangling'; dangling.symlink_to(missing.name)
    for flags in (0, 0x100, 0x200, 0x300):
        check('present flags '+hex(flags), present, flags=flags)
        check('missing flags '+hex(flags), missing, flags=flags, expected=errno.ENOENT)
        c.set_errno(0)
        assert libc.faccessat(-100, os.fsencode(present), 0, flags) == 0, c.get_errno()
    check('symlink target', link)
    check('dangling followed', dangling, expected=errno.ENOENT)
    check('dangling not followed', dangling, flags=0x100)
    check('invalid flags', present, flags=0x40000000, expected=errno.EINVAL)
    check('invalid mode', present, mode=8, expected=errno.EINVAL)
    check('invalid relative dirfd', 'present', fd=999999, expected=errno.EBADF)
    directory = os.open(folder, os.O_RDONLY | os.O_DIRECTORY)
    filefd = os.open(present, os.O_PATH)
    try:
        check('relative directory fd', 'present', fd=directory)
        check('relative symlink nofollow', 'dangling', fd=directory, flags=0x100)
        check('empty path file fd', '', fd=filefd, flags=0x1000)
        check('empty path without flag', '', fd=filefd, expected=errno.ENOENT)
        check('empty path invalid fd', '', fd=999999, flags=0x1000, expected=errno.EBADF)
        check('legacy faccessat present', present, legacy=True)
        check('legacy faccessat missing', missing, legacy=True, expected=errno.ENOENT)
        check('legacy faccessat invalid mode', present, mode=8, legacy=True, expected=errno.EINVAL)
    finally:
        os.close(directory); os.close(filefd)
    for real, effective in ((10000, 65534), (65534, 10000), (10000, 10000)):
        pid = os.fork()
        if pid == 0:
            try:
                os.setgroups([]); os.setresgid(65534, 65534, 65534)
                os.setresuid(real, effective, 0)
                check('real UID permission '+str((real,effective)), present, mode=4,
                      expected=0 if real==10000 else errno.EACCES)
                check('effective UID permission '+str((real,effective)), present, mode=4, flags=0x200,
                      expected=0 if effective==10000 else errno.EACCES)
                check('legacy real UID permission '+str((real,effective)), present, mode=4, legacy=True,
                      expected=0 if real==10000 else errno.EACCES)
                check('execute denied on data file '+str((real,effective)), present, mode=1,
                      expected=errno.EACCES)
                if real == effective == 10000:
                    assert Gio.File.new_for_path(str(present)).query_exists(None)
                    assert not Gio.File.new_for_path(str(missing)).query_exists(None)
                    assert Gio.File.new_for_path(str(dangling)).query_exists(None)
                    print('PASS tablet-user Gio present, absent and dangling-link checks', flush=True)
                os._exit(0)
            except BaseException:
                import traceback; traceback.print_exc(); os._exit(1)
        assert os.waitpid(pid, 0)[1] == 0, (real, effective)
print('FACCESSAT2_AND_GIO_PERMISSION_REGRESSION_PASS', checks, 'parent checks plus child checks', flush=True)
PY
