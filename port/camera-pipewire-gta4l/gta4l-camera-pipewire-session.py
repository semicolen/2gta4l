#!/usr/bin/python3
# SPDX-License-Identifier: MIT
"""Keep one pair of on-demand camera sources in each authorized user session."""
from pathlib import Path
import fcntl,grp,os,signal,stat,subprocess,time

def main():
    if os.getuid()<1000 or grp.getgrnam('video').gr_gid not in os.getgroups():return
    runtime=Path(os.environ['XDG_RUNTIME_DIR'])
    info=runtime.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid!=os.getuid():return
    fd=os.open(runtime/'gta4l-camera-pipewire.lock',os.O_CREAT|os.O_RDWR|os.O_CLOEXEC|os.O_NOFOLLOW,0o600)
    info=os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid():os.close(fd);return
    try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:os.close(fd);return
    children={}
    def stop(*unused):raise SystemExit(0)
    for number in (signal.SIGTERM,signal.SIGINT):signal.signal(number,stop)
    def start(camera):
        child=subprocess.Popen(['/usr/libexec/gta4l-camera-pipewire',camera],stdin=subprocess.DEVNULL)
        children[child.pid]=(camera,child)
    try:
        for camera in ('rear','front'):start(camera)
        while True:
            pid,status=os.waitpid(-1,0)
            camera,child=children.pop(pid)
            child.returncode=os.waitstatus_to_exitcode(status)
            # PipeWire can start after desktop autostart or restart during login.
            time.sleep(3);start(camera)
    finally:
        for camera,child in children.values():
            if child.poll() is None:child.terminate()
        for camera,child in children.values():
            try:child.wait(timeout=4)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=2)
        os.close(fd)

if __name__=='__main__':main()
