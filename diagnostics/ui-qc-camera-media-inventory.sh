#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
code='''from pathlib import Path
import gi
gi.require_version('Gst','1.0')
from gi.repository import Gst
from gi.repository import GLib
for label,value in (('pictures',GLib.UserDirectory.DIRECTORY_PICTURES),('videos',GLib.UserDirectory.DIRECTORY_VIDEOS)):
    folder=Path(GLib.get_user_special_dir(value));counts={}
    for f in folder.rglob('*'):
        if f.is_file():counts[f.suffix.lower()]=counts.get(f.suffix.lower(),0)+1
    print('CAMERA_MEDIA_FILE_COUNTS',label,counts,flush=True)
Gst.init(None)
print('JPEG_MUXER_AVAILABLE',bool(Gst.ElementFactory.find('jifmux')),flush=True)
print('JPEG_PLUGIN_FEATURES',[feature.get_name() for feature in Gst.Registry.get().get_feature_list_by_plugin('jpegformat')],flush=True)
'''
p=subprocess.run(['python3','-c',code],capture_output=True,text=True,timeout=10,**identity);print(p.stdout,p.stderr,flush=True)
PY
