#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess
assert os.getuid()==10000
os.environ['XDG_RUNTIME_DIR']='/run/user/10000'
os.environ['WAYLAND_DISPLAY']=next(p.name for p in Path('/run/user/10000').glob('wayland-*') if p.is_socket())
for name,options in [('Vulkan WSI CPU-copy presentation',{'MESA_VK_WSI_DEBUG':'sw'}),('DRI image presentation',{'LIBGL_KOPPER_DISABLE':'true'})]:
    print('=== '+name+' ===',flush=True)
    env=os.environ.copy()|options
    r=subprocess.run(['timeout','12','gta4l-zink-run','/tmp/gta4l-upload/gpu-wayland-render-test','3'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    print(r.stdout[:10000],flush=True)
    print('test exit',r.returncode,flush=True)
print('GPU_WAYLAND_PRESENT_PROBES_COMPLETE',flush=True)
PY
