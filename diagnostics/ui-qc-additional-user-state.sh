#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os, pwd, grp, stat
assert os.geteuid() == 0
for username in ('tablet', 'quickUser'):
    try: user = pwd.getpwnam(username)
    except KeyError:
        print('USER_NOT_FOUND',username,flush=True);continue
    groups = os.getgrouplist(username, user.pw_gid)
    print('USER',username,'uid',user.pw_uid,'groups',[grp.getgrgid(g).gr_name for g in groups],flush=True)
    for filename in ('.cache/gdm/session.log','.local/state/gdm/session.log'):
        path = Path(user.pw_dir)/filename
        if path.is_file():
            lines = path.read_bytes()[-16384:].decode(errors='replace').splitlines()
            selected = [line for line in lines if any(s in line.lower() for s in ('kgsl','egl','permission denied','failed to initialize','failed to create','fatal','renderer'))]
            print('GPU_SESSION_ERRORS',username,'\n'.join(selected[-15:]),flush=True)
    pid=os.fork()
    if pid==0:
        os.setgroups(groups);os.setgid(user.pw_gid);os.setuid(user.pw_uid)
        for node in ('/dev/kgsl-3d0','/dev/ion'):
            print('USER_GPU_ACCESS',username,node,os.access(node,os.R_OK|os.W_OK),flush=True)
        os._exit(0)
    assert os.waitpid(pid,0)[1]==0
for node in ('/dev/kgsl-3d0','/dev/ion'):
    info=Path(node).stat()
    print('GPU_NODE',node,stat.filemode(info.st_mode),info.st_uid,grp.getgrgid(info.st_gid).gr_name,flush=True)
PY
loginctl list-sessions
