#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import subprocess

assert os.getuid() == 10000
print('=== Mesa versions ===', flush=True)
subprocess.run(['apk','--no-network','info','-v','mesa','mesa-dri-gallium','mesa-egl','mesa-gbm'], check=False)
print('=== EGL diagnostic options ===', flush=True)
subprocess.run(['timeout','5','eglinfo','--help'], check=False)
env = os.environ.copy()
for key in list(env):
    if key.startswith(('LIBGL_', 'GALLIUM_', 'MESA_', 'VK_')) or key == 'QT_QUICK_BACKEND':
        del env[key]
env.update(VK_DRIVER_FILES='/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json', XDG_RUNTIME_DIR='/run/user/10000')
env['WAYLAND_DISPLAY'] = next(p.name for p in Path('/run/user/10000').glob('wayland-*') if p.is_socket())
for name, platform, overrides in [('zink-wayland', 'wayland', {'MESA_LOADER_DRIVER_OVERRIDE':'zink','GALLIUM_DRIVER':'zink','MESA_VK_WSI_DEBUG':'sw'}),
                                 ('zink-wayland-no-kopper', 'wayland', {'MESA_LOADER_DRIVER_OVERRIDE':'zink','GALLIUM_DRIVER':'zink','LIBGL_KOPPER_DISABLE':'true'}),
                                 ('zink-surfaceless-no-kopper', 'surfaceless', {'MESA_LOADER_DRIVER_OVERRIDE':'zink','GALLIUM_DRIVER':'zink','LIBGL_KOPPER_DISABLE':'true'})]:
    print('=== EGL probe: '+name+' ===', flush=True)
    test = env | overrides
    r = subprocess.run(['timeout','15','eglinfo','-B','-p',platform], env=test, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(r.stdout[:14000], flush=True)
    print('probe exit',r.returncode, flush=True)
print('EGL_PROBES_COMPLETE', flush=True)
PY
