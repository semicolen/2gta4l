#!/bin/sh
set -u
python3 - <<'PY'
from pathlib import Path
import os,subprocess
for p in Path('/usr/lib/gta4l-zink/lib').glob('*'):
    if p.is_file() and p.name.startswith(('libgallium','libEGL')):
        data=p.read_bytes()
        print(p.name,'KGSL opt-in string present:', b'GTA4L_ZINK_KGSL' in data,flush=True)
print('Loader paths:',[(str(p),str(p.resolve())) for p in Path('/usr/lib').glob('libvulkan*')],flush=True)
for name,flags in [('default',{}),('no-kopper',{'LIBGL_KOPPER_DISABLE':'true'})]:
    print('=== '+name+' ===',flush=True)
    env=os.environ.copy() | flags | {'VK_LOADER_DEBUG':'all','EGL_LOG_LEVEL':'debug','XDG_RUNTIME_DIR':'/run/user/10000'}
    r=subprocess.run(['timeout','15','gta4l-zink-run','eglinfo','-B','-p','surfaceless'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    print(r.stdout[:20000],flush=True)
    print('exit',r.returncode,flush=True)
PY
echo GPU_ZINK_LOADER_COMPLETE
