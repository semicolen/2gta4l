#!/bin/sh
set -eu
python3 - <<'PY'
import ctypes as c
import subprocess
gio=c.CDLL('libgio-2.0.so.0')
glib=c.CDLL('libglib-2.0.so.0')
class Error(c.Structure):
    _fields_=[('domain',c.c_uint),('code',c.c_int),('message',c.c_char_p)]
gio.g_subprocess_newv.argtypes=[c.POINTER(c.c_char_p),c.c_int,c.POINTER(c.POINTER(Error))]
gio.g_subprocess_newv.restype=c.c_void_p
gio.g_subprocess_wait_check.argtypes=[c.c_void_p,c.c_void_p,c.POINTER(c.POINTER(Error))]
gio.g_subprocess_wait_check.restype=c.c_int
for name in ('g_subprocess_get_if_exited','g_subprocess_get_if_signaled','g_subprocess_get_exit_status','g_subprocess_get_term_sig'):
    getattr(gio,name).argtypes=[c.c_void_p]
    getattr(gio,name).restype=c.c_int
args=['/usr/bin/qmicli','-d','qrtr://0','--loc-set-engine-lock=none']
argv=(c.c_char_p*(len(args)+1))(*[s.encode() for s in args],None)
error=c.POINTER(Error)()
process=gio.g_subprocess_newv(argv,0,c.byref(error))
assert process, error.contents.message.decode() if error else 'no process'
ok=gio.g_subprocess_wait_check(process,None,c.byref(error))
print('GSubprocess success='+str(bool(ok)),flush=True)
if error: print('GSubprocess error='+error.contents.message.decode(),flush=True)
exited=gio.g_subprocess_get_if_exited(process)
signaled=gio.g_subprocess_get_if_signaled(process)
print('exited='+str(exited)+' signaled='+str(signaled),flush=True)
if exited: print('exit_status='+str(gio.g_subprocess_get_exit_status(process)),flush=True)
if signaled: print('termination_signal='+str(gio.g_subprocess_get_term_sig(process)),flush=True)
result=subprocess.run(args,check=False)
print('Python subprocess exit='+str(result.returncode),flush=True)
PY
printf 'GPS_SUBPROCESS_CHECK_END\n'
