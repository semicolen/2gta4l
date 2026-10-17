#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os
assert os.geteuid()==0
print('BOOT_ID',Path('/proc/sys/kernel/random/boot_id').read_text().strip(),flush=True)
print('KERNEL',Path('/proc/version').read_text().strip(),flush=True)
user_shells=[]
for process in Path('/proc').iterdir():
    try:
        if not process.name.isdigit() or (process/'comm').read_text().strip()!='gnome-shell':continue
        uid=process.stat().st_uid
        print('COMPOSITOR',process.name,'uid',uid,flush=True)
        for entry in (process/'environ').read_bytes().split(b'\0'):
            if entry.startswith((b'LIBGL_',b'GALLIUM_',b'MESA_',b'GTA4L_',b'VK_DRIVER_',b'LD_LIBRARY_PATH=')):
                print(entry.decode(),flush=True)
        libraries=sorted({line.split()[-1] for line in (process/'maps').read_text().splitlines()
                          if any(name in line for name in ('libgallium','libvulkan_freedreno','libEGL','libgbm','libLLVM'))})
        print('MAPPED_GRAPHICS_LIBRARIES',libraries,flush=True)
        nodes=[]
        for fd in (process/'fd').iterdir():
            try:
                name=fd.readlink().as_posix()
                if name.startswith(('/dev/kgsl','/dev/ion','/dev/dri/')):nodes.append(name)
            except FileNotFoundError:pass
        print('OPEN_GPU_DISPLAY_NODES',sorted(set(nodes)),flush=True)
        if uid>=10000:user_shells.append((process,libraries,nodes))
    except (FileNotFoundError,ProcessLookupError):pass
assert len(user_shells)==1,'Expected exactly one logged-in user compositor'
process,libraries,nodes=user_shells[0]
assert '/usr/lib/gta4l-zink/lib/libgallium-26.0.8.so' in libraries
assert '/usr/lib/gta4l-kgsl/libvulkan_freedreno.so' in libraries
assert '/dev/kgsl-3d0' in nodes
assert not any('libLLVM' in name for name in libraries)
print('GNOME_USER_COMPOSITOR_PRIVATE_ZINK_AND_ADRENO_DEVICE_VERIFIED',flush=True)
PY
echo '=== Recent GPU/display failure messages ==='
dmesg | grep -Ei 'GPU fault|kgsl.*fault|Kernel panic|BUG:|Unable to handle|out of memory|Killed process' | tail -n 15 || true
