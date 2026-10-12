#!/bin/sh
set -eu
timeout 28 unshare -m /bin/sh -s <<'NAMESPACE'
set -eu
ROOT=/opt/gta4l-camera-dev/r0
mount --make-rprivate /
mount --bind /dev "$ROOT/dev"
mount --bind /proc "$ROOT/proc"
mount -o remount,bind,ro "$ROOT/proc"
mount --bind /sys "$ROOT/sys"
mount -o remount,bind,ro "$ROOT/sys"
python3 - <<'PY'
import ctypes
import os
from pathlib import Path
import signal
import struct

libc = ctypes.CDLL(None, use_errno=True)
libc.ptrace.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
libc.ptrace.restype = ctypes.c_long
def ptrace(request, pid, address=0, data=0):
    result = libc.ptrace(request, pid, address, data)
    if result == -1:
        raise OSError(ctypes.get_errno(), 'ptrace')
    return result
pid = os.fork()
if pid == 0:
    ptrace(0, 0)  # TRACEME; subsequent exec stops at SIGTRAP.
    os.environ['LD_LIBRARY_PATH'] = '/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/apex/com.android.vndk.v31/lib64:/system/lib64'
    os.execvp('chroot', ['chroot', '/opt/gta4l-camera-dev/r0',
                        '/system/bin/camera-hal-enumerate', '--enumerate'])
try:
    _, status = os.waitpid(pid, 0)
    assert os.WIFSTOPPED(status)
    ptrace(0x4200, pid, 0, 0x100000)  # SETOPTIONS, EXITKILL.
    ptrace(7, pid)
    while True:
        _, status = os.waitpid(pid, 0)
        if os.WIFEXITED(status):
            print('Camera helper exited='+str(os.WEXITSTATUS(status)))
            break
        if os.WIFSIGNALED(status):
            print('Camera helper signal='+str(os.WTERMSIG(status)))
            break
        sig = os.WSTOPSIG(status)
        if sig == signal.SIGSEGV:
            class Iovec(ctypes.Structure):
                _fields_ = [('base', ctypes.c_void_p), ('length', ctypes.c_size_t)]
            registers = (ctypes.c_uint64 * 34)()
            vec = Iovec(ctypes.addressof(registers), ctypes.sizeof(registers))
            ptrace(0x4204, pid, 1, ctypes.byref(vec))  # GETREGSET, NT_PRSTATUS.
            maps = Path('/proc/'+str(pid)+'/maps').read_text().splitlines()
            def describe(addr):
                for line in maps:
                    parts = line.split(None, 5)
                    lo, hi = (int(v, 16) for v in parts[0].split('-'))
                    if lo <= addr < hi:
                        name = parts[5] if len(parts) == 6 else '(anonymous)'
                        offset = addr-lo+int(parts[2], 16)
                        return name+' +0x%x' % offset
                return '(unmapped) 0x%x' % addr
            print('SIGSEGV pc='+describe(registers[32]))
            print('SIGSEGV lr='+describe(registers[30]))
            print('SIGSEGV sp=0x%x fp=0x%x' % (registers[31], registers[29]))
            for index in range(8):
                print('x%d=0x%x' % (index, registers[index]))
            fp = registers[29]
            try:
                with Path('/proc/'+str(pid)+'/mem').open('rb', buffering=0) as mem:
                    for i in range(12):
                        if fp == 0 or fp % 16: break
                        mem.seek(fp)
                        previous, link = struct.unpack('<QQ', mem.read(16))
                        print('frame%d=%s' % (i, describe(link)))
                        if previous <= fp or previous-fp > 1024*1024: break
                        fp = previous
            except (OSError, struct.error) as exc:
                print('Frame walk stopped: '+str(exc))
            ptrace(7, pid, 0, sig)
        else:
            ptrace(7, pid, 0, 0 if sig in (signal.SIGTRAP, signal.SIGSTOP) else sig)
finally:
    try: os.kill(pid, signal.SIGKILL)
    except ProcessLookupError: pass
print('CAMERA_HAL_CRASH_TRACE_END')
PY
NAMESPACE
