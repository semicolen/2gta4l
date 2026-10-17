#!/bin/sh
# Private account backup requested for later clean UI tests. Never print hashes.
set -eu
umask 077
python3 - <<'PY'
from pathlib import Path
import grp,hashlib,io,json,os,pwd,tarfile
assert os.geteuid()==0
user=pwd.getpwnam('quickUser')
assert user.pw_uid==10001 and user.pw_gid==10001 and user.pw_dir=='/home/quickUser'
groups=[grp.getgrgid(g).gr_name for g in os.getgrouplist(user.pw_name,user.pw_gid)]
assert set(groups)=={'quickUser','wheel','audio','video','netdev','plugdev'}
rows=[line.split(':') for line in Path('/etc/shadow').read_text().splitlines() if line.startswith(user.pw_name+':')]
assert len(rows)==1 and rows[0][1].startswith('$')
metadata={'username':user.pw_name,'uid':user.pw_uid,'gid':user.pw_gid,'home':user.pw_dir,
          'shell':user.pw_shell,'gecos':user.pw_gecos,'groups':groups,'encrypted_password':rows[0][1]}
folder=Path('/home/tablet/.cache/gta4l-ui-qc')
folder.mkdir(mode=0o700,parents=True,exist_ok=True);os.chown(folder,10000,10000)
target=folder/'quickUser-before-ui-r13.tar.gz'
assert not target.exists()
sources=[Path(user.pw_dir)/name for name in ('.config','Pictures','.local/share/keyrings')]
sources=[p for p in sources if p.exists()]
size=sum(p.stat().st_size for root in sources for p in ([root] if root.is_file() else root.rglob('*')) if p.is_file() and not p.is_symlink())
assert size<25*1024*1024,'Save a larger private backup before proceeding'
with tarfile.open(target,'x:gz') as archive:
    data=(json.dumps(metadata)+'\n').encode()
    entry=tarfile.TarInfo('account.json');entry.mode=0o600;entry.size=len(data)
    archive.addfile(entry,io.BytesIO(data))
    for source in sources:archive.add(source,arcname=source.as_posix().lstrip('/'))
target.chmod(0o600);os.chown(target,10000,10000)
assert target.stat().st_size<32*1024*1024
with target.open('rb') as source:digest=hashlib.file_digest(source,'sha256').hexdigest()
print('PRIVATE_ACCOUNT_BACKUP',target.stat().st_size,digest,flush=True)
PY
