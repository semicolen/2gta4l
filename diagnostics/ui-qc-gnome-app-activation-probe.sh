#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import dbus,os,subprocess,time
assert os.getuid()==10000
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid==os.getuid() and (p/'comm').read_text().strip()=='gnome-shell')
environment=dict(entry.decode().split('=',1) for entry in (shell/'environ').read_bytes().split(b'\0') if b'=' in entry)
os.environ.clear();os.environ.update(environment)
sockets=[p for p in Path(os.environ['XDG_RUNTIME_DIR']).glob('wayland-*') if p.is_socket()]
assert len(sockets)==1;os.environ['WAYLAND_DISPLAY']=sockets[0].name
os.environ['GSK_RENDERER']='gl';os.environ['LIBGL_ALWAYS_SOFTWARE']='0'
keys=('GSK_RENDERER','LIBGL_ALWAYS_SOFTWARE','GALLIUM_DRIVER','MESA_LOADER_DRIVER_OVERRIDE','GTA4L_ZINK_KGSL','LIBGL_DRIVERS_PATH','LIBGL_KOPPER_DISABLE','LD_LIBRARY_PATH','VK_DRIVER_FILES','WAYLAND_DISPLAY','XDG_RUNTIME_DIR','DISPLAY','XAUTHORITY')
bus=dbus.SessionBus()
api=dbus.Interface(bus.get_object('org.freedesktop.DBus','/org/freedesktop/DBus'),'org.freedesktop.DBus')
api.UpdateActivationEnvironment({key:os.environ[key] for key in keys if key in os.environ})
print('SESSION_BUS_ACTIVATION_ENVIRONMENT_UPDATED_WITH_TESTED_GL_PATH',flush=True)
obj=bus.get_object('org.gnome.Settings','/org/gnome/Settings')
dbus.Interface(obj,'org.freedesktop.Application').Activate(dbus.Dictionary(signature='sv'),timeout=15)
time.sleep(5)
owner=api.GetNameOwner('org.gnome.Settings');pid=int(api.GetConnectionUnixProcessID(owner))
process=Path('/proc')/str(pid)
print('DBUS_ACTIVATED_SETTINGS_PID',pid,flush=True)
for entry in (process/'environ').read_bytes().split(b'\0'):
    if entry.startswith((b'GSK_RENDERER=',b'LIBGL_ALWAYS_SOFTWARE=',b'GALLIUM_DRIVER=',b'LD_LIBRARY_PATH=')):
        print(entry.decode(),flush=True)
libraries=sorted({line.split()[-1] for line in (process/'maps').read_text().splitlines() if any(v in line for v in ('libgallium','libvulkan_freedreno','libLLVM'))})
print('DBUS_ACTIVATED_GRAPHICS_LIBRARIES',libraries,flush=True)
assert '/usr/lib/gta4l-zink/lib/libgallium-26.0.8.so' in libraries
assert '/usr/lib/gta4l-kgsl/libvulkan_freedreno.so' in libraries
print('DBUS_ACTIVATED_SETTINGS_RUNNING_ON_ADRENO; window left open for review',flush=True)
PY
