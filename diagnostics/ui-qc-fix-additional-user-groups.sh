#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import json,os,pwd,grp,subprocess
assert os.geteuid()==0
user=pwd.getpwnam('quickUser')
assert user.pw_uid==10001 and user.pw_dir=='/home/quickUser'
groups=('audio','video','netdev','plugdev')
before=[grp.getgrgid(g).gr_name for g in os.getgrouplist(user.pw_name,user.pw_gid)]
backup=Path('/var/lib/gta4l-ui-qc/quickUser-groups-before.json')
assert not backup.exists()
backup.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
backup.write_text(json.dumps({'user':user.pw_name,'uid':user.pw_uid,'groups':before},indent=2)+'\n')
backup.chmod(0o600)
for name in groups:
    grp.getgrnam(name)
    if name not in before:subprocess.run(['addgroup',user.pw_name,name],check=True)
after=[grp.getgrgid(g).gr_name for g in os.getgrouplist(user.pw_name,user.pw_gid)]
assert set(after)==set(before)|set(groups)
os.sync()
print('QUICKUSER_HARDWARE_GROUPS_ADDED',after,flush=True)
PY
