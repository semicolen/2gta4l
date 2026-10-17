#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import os,pwd,subprocess,json
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
for kind in ('cards','modules','sources'):
    objects=json.loads(subprocess.check_output(['pactl','-f','json','list',kind],text=True,timeout=10,**identity))
    print('PULSE_JSON',kind,'type',type(objects).__name__,'count',len(objects),'keys',[list(obj) for obj in objects][:3])
    for obj in objects:
        if kind=='modules' and obj.get('name')=='module-alsa-card':print('INTERNAL_MODULE',obj)
        if kind=='cards':print('CARD_OWNER',obj.get('owner_module'))
schema=Path('/usr/share/glib-2.0/schemas/org.gnome.Snapshot.gschema.xml')
if schema.exists():
    import xml.etree.ElementTree as ET
    root=ET.parse(schema).getroot()
    for e in root.findall('enum'):print('SNAPSHOT_SCHEMA_ENUM',e.get('id'),[(v.get('nick'),v.get('value')) for v in e])
print('CURRENT_CAPTURE_MODE',subprocess.check_output(['gsettings','get','org.gnome.Snapshot','capture-mode'],text=True,timeout=5,**identity))
PY
