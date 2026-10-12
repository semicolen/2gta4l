#!/bin/sh
set -eu
python3 - <<'PY'
import json,socket,time
from pathlib import Path
address='/run/gta4l-camera/control.sock'
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(20);peer.connect(address);source=peer.makefile('rb')
    def request(command):
        peer.sendall(command.encode()+b'\n')
        return json.loads(source.readline())
    assert request('photo')=={'error':'Start a camera before taking a photo'}
    assert request('photo-done')=={'error':'No completed photo capture'}
    request('rear')
    deadline=time.monotonic()+20
    while request('status')['frames']<2:
        assert time.monotonic()<deadline
        time.sleep(.3)
    request('photo');deadline=time.monotonic()+15
    while True:
        result=request('status')
        if result['frames']>=2 and result['running']:break
        assert time.monotonic()<deadline,result
        time.sleep(.3)
    print('CAMERA_FULL_PHOTO_CANCELLED_AT_FRAME='+str(result['frames']))
    source.close()
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(20);peer.connect(address);peer.sendall(b'status\n')
    result=json.loads(peer.makefile('rb').readline())
    assert result['running'] is False and result['camera'] is None,result
assert not Path('/run/gta4l-camera/frames/photo.ppm').exists()
assert not Path('/run/gta4l-camera/frames/frame.ppm').exists()
log=Path('/var/lib/gta4l-camera/last-session.log').read_text()
assert 'preview=0 stop_requested=1' in log
assert 'CAMERA_FLUSH id=0 result=0' in log
assert 'CAMERA_CLOSE id=0 result=0' in log and 'CAMERA_BUFFER_RELEASE result=0' in log
assert 'CAMERA_IMAGE_SAVED success=1' not in log
print('CAMERA_FULL_PHOTO_DISCONNECT_CANCEL_AND_CLEANUP_PASSED')
PY
