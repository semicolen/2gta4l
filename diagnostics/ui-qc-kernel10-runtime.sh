#!/bin/sh
set -eu
uname -a
grep -Eq '#(10|11)-postmarketOS' /proc/version
python3 - <<'PY'
import os,errno,time,signal
from pathlib import Path
print('=== P_PIDFD ownership, status and descriptor checks ===',flush=True)
def error_case(label,fn,expected):
    try:fn()
    except OSError as error:
        assert error.errno==expected,(label,error)
        print('PASS',label,errno.errorcode[error.errno],flush=True)
    else:raise AssertionError(label+' unexpectedly succeeded')
error_case('negative descriptor',lambda:os.waitid(os.P_PIDFD,-1,os.WEXITED),errno.EINVAL)
error_case('closed descriptor',lambda:os.waitid(os.P_PIDFD,999999,os.WEXITED),errno.EBADF)
regular=os.open('/dev/null',os.O_RDONLY)
try:error_case('non-pid descriptor',lambda:os.waitid(os.P_PIDFD,regular,os.WEXITED),errno.EBADF)
finally:os.close(regular)
self_fd=os.pidfd_open(os.getpid())
try:error_case('not a child',lambda:os.waitid(os.P_PIDFD,self_fd,os.WEXITED|os.WNOHANG),errno.ECHILD)
finally:os.close(self_fd)
read_fd,write_fd=os.pipe()
pid=os.fork()
if pid==0:
    os.close(write_fd)
    os.read(read_fd,1)
    os._exit(23)
os.close(read_fd)
fd=None
reaped=False
try:
    fd=os.pidfd_open(pid)
    assert os.waitid(os.P_PIDFD,fd,os.WEXITED|os.WNOHANG) is None
    print('PASS running child WNOHANG',flush=True)
    os.write(write_fd,b'x');os.close(write_fd);write_fd=None
    seen=os.waitid(os.P_PIDFD,fd,os.WEXITED|os.WNOWAIT)
    assert seen.si_pid==pid and seen.si_status==23 and seen.si_code==os.CLD_EXITED,seen
    print('PASS exited child WNOWAIT preserves status',flush=True)
    waited=os.waitid(os.P_PIDFD,fd,os.WEXITED)
    reaped=True
    assert waited.si_pid==pid and waited.si_status==23,waited
    error_case('already reaped',lambda:os.waitid(os.P_PIDFD,fd,os.WEXITED|os.WNOHANG),errno.ECHILD)
    print('PASS child reaped through pidfd',flush=True)
finally:
    if write_fd is not None:os.close(write_fd)
    if fd is not None:os.close(fd)
    if not reaped:
        try:os.kill(pid,signal.SIGKILL)
        except ProcessLookupError:pass
        os.waitpid(pid,0)
print('=== Himax actual key bits ===',flush=True)
device=next(p for p in Path('/sys/class/input').glob('event*') if (p/'device/name').read_text().strip()=='himax-touchscreen')
words=(device/'device/capabilities/key').read_text().split()
bits=int(''.join(w.zfill(16) for w in words),16)
assert not any((bits>>key)&1 for key in range(272,276))
assert all((bits>>key)&1 for key in range(183,187))
assert (bits>>330)&1
print('PASS no BTN_LEFT/RIGHT/MIDDLE/SIDE; gesture F13-F16 and BTN_TOUCH retained',flush=True)
print('KERNEL_PIDFD_RUNTIME_API_AND_HIMAX_BITS_PASS',flush=True)
PY
/usr/sbin/libinput list-devices | sed -n '/Device:.*himax/,/^$/p'
echo '=== Kernel errors ==='
dmesg | grep -Ei 'Kernel panic|BUG:|Unable to handle|GPU fault|kgsl.*fault|watchdog.*bite' | tail -n 25 || true
