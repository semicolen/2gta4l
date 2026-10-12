#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,socket,subprocess,sys
address='/run/gta4l-camera/control.sock'
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
    client.settimeout(3); client.connect(address)
    source=client.makefile('rb')
    for command in ('status','rear; touch /tmp/gta4l-camera-invalid-command','../../etc/shadow','status'):
        client.sendall(command.encode()+b'\n')
        result=json.loads(source.readline())
        if command=='status':
            assert result['running'] is False and result['camera'] is None
            print('CAMERA_CONTROLLER_IDLE_CONFIRMED')
        else:
            assert result=={'error':'Unsupported camera command'}
            print('CAMERA_CONTROLLER_INVALID_COMMAND_REJECTED')
assert not Path('/tmp/gta4l-camera-invalid-command').exists()
code="""import socket
try:
 s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect('/run/gta4l-camera/control.sock')
except PermissionError:
 print('CAMERA_CONTROLLER_UNPRIVILEGED_ACCESS_DENIED')
else:
 raise SystemExit(1)
"""
def unprivileged():
    os.setgroups([]); os.setgid(65534); os.setuid(65534)
subprocess.run([sys.executable,'-c',code],preexec_fn=unprivileged,check=True)
leaks=[line for line in Path('/proc/1/mountinfo').read_text().splitlines()
       if '/usr/lib/gta4l-camera/runtime/' in line or '/opt/gta4l-camera-dev/' in line]
assert not leaks
assert not Path('/run/gta4l-camera/frames/frame.ppm').exists()
print('CAMERA_GLOBAL_MOUNT_LEAKS=0')
print('CAMERA_CONTROLLER_CHECK_PASSED')
PY
