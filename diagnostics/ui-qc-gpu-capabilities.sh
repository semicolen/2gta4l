#!/bin/sh
set -eu
python3 - <<'PY'
import os
from pathlib import Path
import shutil
import subprocess

assert os.getuid() == 10000
sessions = []
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid == os.getuid() and (p/'comm').read_text().strip() == 'kwin_wayland':
            sessions.append(p)
    except (FileNotFoundError, ProcessLookupError):
        pass
assert len(sessions) == 1, 'Expected one Plasma desktop session'
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'DBUS_SESSION_BUS_ADDRESS=', b'XDG_RUNTIME_DIR=', b'WAYLAND_DISPLAY=', b'DISPLAY=', b'XAUTHORITY=')):
        key, value = entry.decode().split('=', 1)
        os.environ[key] = value
print('=== Installed graphics packages ===', flush=True)
pkgs = subprocess.check_output(['apk','--no-network','info'], text=True).splitlines()
print('\n'.join(x for x in pkgs if any(s in x for s in ('mesa', 'vulkan', 'libdrm', 'epoxy', 'glmark'))), flush=True)
print('=== Driver files and tools ===', flush=True)
for pattern in ('/usr/lib/dri/*', '/usr/lib/lib*GL*', '/usr/share/gta4l-kgsl/*'):
    import glob
    print(pattern, glob.glob(pattern), flush=True)
for tool in ('glxinfo','eglinfo','vulkaninfo','vkcube','glmark2','glmark2-es2','glmark2-wayland'):
    print(tool, shutil.which(tool), flush=True)
print('=== Kernel GPU interfaces ===', flush=True)
for path in ('/dev/kgsl-3d0','/dev/ion','/dev/dri/card0','/dev/dri/renderD128', '/sys/class/kgsl/kgsl-3d0/gpu_model'):
    p = Path(path)
    print(path, 'exists='+str(p.exists()), flush=True)
    if path.endswith('gpu_model') and p.exists():
        print(p.read_text().strip(), flush=True)
print('=== Current desktop environment ===', flush=True)
for entry in (sessions[0]/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'LIBGL_', b'GALLIUM_', b'QT_QUICK_BACKEND=', b'KWIN_', b'MESA_')):
        print(entry.decode(), flush=True)
env = os.environ.copy()
env['VK_DRIVER_FILES'] = '/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json'
print('=== Turnip summary ===', flush=True)
subprocess.run(['timeout','20','vulkaninfo','--summary'], env=env, check=False)
print('=== Turnip extensions and Zink-relevant features ===', flush=True)
r = subprocess.run(['timeout','25','vulkaninfo'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
print('vulkaninfo exit', r.returncode, flush=True)
print(r.stderr[-4000:], flush=True)
need = ('VK_KHR_', 'VK_EXT_', 'logicOp', 'fillModeNonSolid', 'alphaToOne', 'shaderClipDistance', 'scalarBlockLayout', 'customBorderColorWithoutFormat', 'timelineSemaphore', 'provokingVertex', 'rectangularLines', 'bresenhamLines', 'smoothLines')
for line in r.stdout.splitlines():
    if any(x in line for x in need):
        print(line, flush=True)
print('GPU_CAPABILITIES_COMPLETE', flush=True)
PY
