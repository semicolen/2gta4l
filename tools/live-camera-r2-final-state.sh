#!/bin/sh
set -eu
rc-service gta4l-camera status
test -e /etc/runlevels/default/gta4l-camera
printf '%s\n' 'bdf12e1ac960d282f832dc37f98c84b3a87e31c6d5d1f1555895c6a087142429  /usr/lib/gta4l-camera/runtime/system/bin/camera-hal-enumerate' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import json,socket,struct,stat
print('boot_id='+Path('/proc/sys/kernel/random/boot_id').read_text().strip())
expected={'camera-gta4l':'1.0-r2','camera-gta4l-openrc':'1.0-r2',
          'device-samsung-gta4l':'1-r21','gps-gta4l':'1.0-r3'}
installed={}
for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
    values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if values.get('P') in expected:installed[values['P']]=values['V']
assert installed==expected,installed
print('CAMERA_FINAL_INSTALLED_PACKAGES='+json.dumps(installed,sort_keys=True))
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(20);peer.connect('/run/gta4l-camera/control.sock');peer.sendall(b'status\n')
    response=json.loads(peer.makefile('rb').readline())
    assert response['running'] is False and response['camera'] is None,response
for name in ('frame.ppm','photo.ppm'):
    assert not list(Path('/run/gta4l-camera/frames').glob(name+'*'))
for path in Path('/proc').iterdir():
    if not path.name.isdigit():continue
    try:args=(path/'cmdline').read_bytes().split(b'\0')
    except FileNotFoundError:continue
    assert b'/system/bin/camera-hal-enumerate' not in args
leaks=[line for line in Path('/proc/1/mountinfo').read_text().splitlines()
       if '/usr/lib/gta4l-camera/runtime/' in line or '/opt/gta4l-camera-dev/' in line]
assert not leaks
photos=sorted(Path('/home/tablet/Pictures/Camera').glob('*.png'),key=lambda p:p.stat().st_mtime)
print('saved_photos='+str(len(photos)))
for photo in photos[-10:]:
    with photo.open('rb') as image:header=image.read(24)
    assert header[:8]==b'\x89PNG\r\n\x1a\n'
    width,height=struct.unpack('>II',header[16:24])
    print('photo bytes=%d width=%d height=%d mode=%s name=%s' %
          (photo.stat().st_size,width,height,oct(stat.S_IMODE(photo.stat().st_mode)),photo.name))
print('CAMERA_R2_POST_REBOOT_IDLE_AND_CLEANUP_VERIFIED')
PY
head -c 28938256 /dev/mmcblk0p69 | sha256sum
printf 'CAMERA_R2_FINAL_STATE_END\n'
