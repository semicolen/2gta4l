#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,socket,time,stat,hashlib
CAMERA='rear'
SIZE=(3264, 2448)
with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as peer:
    peer.settimeout(20);peer.connect('/run/gta4l-camera/control.sock')
    source=peer.makefile('rb')
    def request(command):
        peer.sendall(command.encode()+b'\n')
        response=json.loads(source.readline())
        assert 'error' not in response,response
        return response
    request(CAMERA)
    deadline=time.monotonic()+20
    while True:
        result=request('status')
        if result['running'] and result['frames']>=2:break
        assert time.monotonic()<deadline,result
        time.sleep(.3)
    print('CAMERA_PREVIEW_BEFORE_PHOTO camera='+CAMERA+' frames='+str(result['frames']))
    start=time.monotonic();request('photo');deadline=start+27
    while True:
        result=request('status')
        if result['exit_status'] is not None:break
        assert time.monotonic()<deadline,result
        time.sleep(.3)
    assert result['photo_ready'] and result['exit_status']==0,result
    photo=Path('/run/gta4l-camera/frames/photo.ppm')
    with photo.open('rb') as image:
        assert image.readline()==b'P6\n'
        size=tuple(map(int,image.readline().split()))
        assert size==SIZE,size
        assert image.readline()==b'255\n'
        assert photo.stat().st_size==image.tell()+size[0]*size[1]*3
    metadata=photo.stat()
    assert metadata.st_uid==0 and metadata.st_gid==27 and stat.S_IMODE(metadata.st_mode)==0o640
    digest=hashlib.sha256(photo.read_bytes()).hexdigest()
    print('CAMERA_FULL_PHOTO_OK camera=%s width=%d height=%d frames=%d seconds=%.2f sha256=%s' %
          (CAMERA,*size,result['frames'],time.monotonic()-start,digest))
    request('photo-done');deadline=time.monotonic()+20
    while True:
        result=request('status')
        if result['mode']=='preview' and result['running'] and result['frames']>=1:break
        assert time.monotonic()<deadline,result
        time.sleep(.3)
    assert not photo.exists()
    print('CAMERA_PREVIEW_RESUMED_AFTER_FULL_PHOTO camera='+CAMERA)
    source.close()
deadline=time.monotonic()+15
while Path('/run/gta4l-camera/frames/frame.ppm').exists() or Path('/run/gta4l-camera/frames/photo.ppm').exists():
    assert time.monotonic()<deadline,'Camera did not release temporary frames after disconnect'
    time.sleep(.2)
assert not Path('/run/gta4l-camera/frames/frame.ppm').exists()
assert not Path('/run/gta4l-camera/frames/photo.ppm').exists()
print('CAMERA_PHOTO_DISCONNECT_CLEANUP_OK camera='+CAMERA)
PY
