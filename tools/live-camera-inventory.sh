#!/bin/sh
set -eu
printf '=== Camera device and driver inventory (no image capture) ===\n'
python3 - <<'PY'
from pathlib import Path
import os
import fcntl
import struct
for name in ('rear/rear_camtype','front/front_camtype'):
    p=Path('/sys/class/camera')/name
    if p.exists(): print('camera_type '+name+'='+p.read_text().strip())
for entry in sorted(Path('/sys/class/video4linux').glob('*')):
    name=(entry/'name').read_text().strip()
    print(entry.name+' name='+name)
    if not entry.name.startswith('video'): continue
    fd=None
    try:
        fd=os.open('/dev/'+entry.name,os.O_RDWR|os.O_NONBLOCK)
        cap=bytearray(104)
        fcntl.ioctl(fd,0x80685600,cap,True)
        def text(offset,size): return bytes(cap[offset:offset+size]).split(b'\0')[0].decode(errors='replace')
        print(' driver='+text(0,16)+' card='+text(16,32)+' bus='+text(48,32))
        print(' capabilities=0x%08x device_caps=0x%08x'%struct.unpack_from('II',cap,84))
    except OSError as exc: print(' querycap_error='+str(exc))
    finally:
        if fd is not None: os.close(fd)
for entry in sorted(Path('/sys/class/media').glob('*')):
    model=entry/'model'
    print(entry.name+' model='+(model.read_text().strip() if model.exists() else '(unavailable)'))
for entry in sorted(Path('/sys/bus/platform/drivers').glob('*')):
    if any(word in entry.name.lower() for word in ('cam','cci','csid','ife','vfe','isp')):
        devices=[p.name for p in entry.iterdir() if p.is_symlink() and p.name!='module']
        print('platform_driver='+entry.name+' devices='+','.join(devices))
PY
printf '=== Camera kernel messages ===\n'
dmesg | grep -Ei 'camera|cam_req|cam_sensor|cam_cci|cam_csiphy|cam_ife|cam_icp|cam_cpas|cam_smmu' | tail -n 100 || true
printf 'CAMERA_INVENTORY_END\n'
