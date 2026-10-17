#!/bin/sh
set -eu
python3 - <<'PY'
import os, errno, subprocess
from pathlib import Path
print('GNOME_CHILD_WAIT_COMPATIBILITY', flush=True)
print(subprocess.check_output(['apk','--no-network','info','-v','glib','gnome-session'],text=True),flush=True)
for process in Path('/proc').iterdir():
    try:
        if not process.name.isdigit() or process.stat().st_uid != 10000: continue
        if (process/'comm').read_text().strip() != 'gnome-session-b': continue
        print('SESSION', process.name, 'wait', (process/'wchan').read_text().strip(),flush=True)
        children=(process/'task'/process.name/'children').read_text().split()
        for pid in children:
            child=Path('/proc')/pid
            print('CHILD',pid,' '.join(line for line in (child/'status').read_text().splitlines()
                    if line.startswith(('Name:','State:','PPid:'))),flush=True)
        for fd in (process/'fd').iterdir():
            if fd.readlink().as_posix()=='anon_inode:[pidfd]':
                print('PIDFD',fd.name,(process/'fdinfo'/fd.name).read_text(),flush=True)
    except (FileNotFoundError,ProcessLookupError,PermissionError): pass
pid=os.fork()
if pid == 0: os._exit(0)
fd=None
reaped=False
try:
    try:
        fd=os.pidfd_open(pid)
        print('PIDFD_OPEN_OK',flush=True)
        result=os.waitid(os.P_PIDFD,fd,os.WEXITED)
        reaped=True
        print('PIDFD_WAITID_OK',result,flush=True)
    except OSError as error:
        print('PIDFD_WAIT_ERROR',error.errno,errno.errorcode.get(error.errno),str(error),flush=True)
finally:
    if fd is not None: os.close(fd)
    if not reaped: print('WAITPID_FALLBACK',os.waitpid(pid,0),flush=True)
print('GNOME_CHILD_WAIT_CHECK_COMPLETE',flush=True)
PY
printf '\nSession launcher options\n'
gnome-session --help
