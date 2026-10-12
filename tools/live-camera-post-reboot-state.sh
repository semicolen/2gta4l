#!/bin/sh
set -eu
printf '=== Boot identity and packages ===\n'
cat /proc/sys/kernel/random/boot_id
uptime
uname -r
apk info -v camera-gta4l camera-gta4l-openrc device-samsung-gta4l gps-gta4l
printf '=== Automatic camera startup ===\n'
rc-service gta4l-camera status
test -e /etc/runlevels/default/gta4l-camera
test -S /run/gta4l-camera/control.sock
python3 - <<'PY'
import json,socket
from pathlib import Path
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(3); peer.connect('/run/gta4l-camera/control.sock'); peer.sendall(b'status\n')
    result=json.loads(peer.makefile('rb').readline())
    assert result['running'] is False and result['camera'] is None
    print('CAMERA_CONTROLLER_STARTED_IDLE_AFTER_REBOOT')
assert not Path('/run/gta4l-camera/frames/frame.ppm').exists()
PY
printf '=== Display and desktop session ===\n'
pgrep -a -x Xorg || true
pgrep -a -u tablet -x xfce4-session || true
printf 'CAMERA_POST_REBOOT_STATE_END\n'
