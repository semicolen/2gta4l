#!/bin/sh
set -eu
rc-service gta4l-camera status || true
printf '=== Controller and camera processes ===\n'
ps -eo pid,ppid,user,comm,args | grep -E 'gta4l-camera-service.py|/usr/bin/gta4l-camera|camera-hal-enumerate' | grep -v grep || true
printf '=== Native application diagnostics ===\n'
cat /home/tablet/.cache/gta4l-camera/camera-app.log
printf '=== Frame and saved-photo metadata ===\n'
python3 - <<'PY'
from pathlib import Path
import os,stat,time,struct
print('boot_id='+Path('/proc/sys/kernel/random/boot_id').read_text().strip())
frame=Path('/run/gta4l-camera/frames/frame.ppm')
if frame.exists():
    s=frame.stat()
    print('frame bytes=%d uid=%d gid=%d mode=%s age_seconds=%.3f' %
          (s.st_size,s.st_uid,s.st_gid,oct(stat.S_IMODE(s.st_mode)),time.time()-s.st_mtime))
else: print('frame absent (idle or still starting)')
photos=sorted((Path('/home/tablet/Pictures/Camera')).glob('*.png'),key=lambda path:path.stat().st_mtime)
print('saved_photos='+str(len(photos)))
for p in photos[-3:]:
    with p.open('rb') as image: header=image.read(24)
    assert header[:8]==b'\x89PNG\r\n\x1a\n'
    width,height=struct.unpack('>II',header[16:24])
    print('photo bytes=%d width=%d height=%d mode=%s name=%s' %
          (p.stat().st_size,width,height,oct(stat.S_IMODE(p.stat().st_mode)),p.name))
log=Path('/var/lib/gta4l-camera/last-session.log')
if log.exists(): print('\n'.join(log.read_text(errors='replace').splitlines()[-22:]))
photo_log=Path('/var/lib/gta4l-camera/last-photo.log')
if photo_log.exists():
    print('=== Last full-photo diagnostics ===')
    print('\n'.join(photo_log.read_text(errors='replace').splitlines()[-36:]))
PY
printf 'CAMERA_APP_STATE_END\n'
