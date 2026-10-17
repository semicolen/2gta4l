#!/bin/sh
# Read failure evidence without taking the camera away from an open application.
set -u
rc-service gta4l-camera status
free -m
python3 - <<'PY'
from pathlib import Path
import struct
for p in Path('/proc').iterdir():
    try:
        if not p.name.isdigit(): continue
        args=(p/'cmdline').read_bytes().split(b'\0')
        if not any(v in args for v in (b'/usr/bin/gta4l-camera', b'/system/bin/camera-hal-enumerate', b'/usr/libexec/gta4l-camera-service.py')):
            continue
        print('CAMERA_PROCESS', p.name)
        print('\n'.join(line for line in (p/'status').read_text().splitlines()
                        if line.startswith(('Name:','Uid:','VmRSS:','VmPeak:','Threads:'))))
    except (FileNotFoundError,ProcessLookupError):
        pass
for name in ('/home/tablet/.cache/gta4l-ui-qc/camera.log',
             '/var/lib/gta4l-camera/last-photo.log','/var/lib/gta4l-camera/last-session.log'):
    p=Path(name)
    print('\nLOG',name)
    if p.exists(): print('\n'.join(p.read_text(errors='replace').splitlines()[-90:]))
    else: print('absent')
for name in ('frame.ppm','photo.ppm'):
    p=Path('/run/gta4l-camera/frames')/name
    print('FRAME',name,'bytes',p.stat().st_size if p.exists() else 'absent')
photos=list(Path('/home/tablet/Pictures/Camera').glob('*.png'))
print('SAVED_PHOTO_COUNT',len(photos))
for p in photos[-3:]:
    with p.open('rb') as f: header=f.read(24)
    print('PNG',struct.unpack('>II',header[16:24]),'bytes',p.stat().st_size)
PY
printf '\nKERNEL_CAMERA_AND_MEMORY_ERRORS\n'
dmesg | grep -Ei 'out of memory|killed process|segfault|camera-hal|cam_req_mgr|CAM_ERR' | tail -n 65
printf '\nCAMERA_FAILURE_DIAGNOSTIC_END\n'
