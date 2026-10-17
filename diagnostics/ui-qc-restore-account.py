#!/usr/bin/env python3
"""Restore an explicitly requested QC account into a freshly installed rootfs."""
from pathlib import Path
import grp,json,os,pwd,subprocess,sys

assert os.geteuid()==0
source=Path(sys.argv[1])
assert source==Path('/tmp/gta4l-qc-account/account.json')
data=json.loads(source.read_text())
assert data['username']=='quickUser' and data['uid']==data['gid']==10001
assert data['home']=='/home/quickUser' and data['shell'] in ('/bin/ash','/bin/sh','/bin/bash')
assert Path(data['shell']).is_file() and '\n' not in data['gecos'] and ':' not in data['gecos']
expected={'quickUser','wheel','audio','video','netdev','plugdev'}
assert set(data['groups'])==expected
secret=data['encrypted_password']
assert secret.startswith('$') and not any(c in secret for c in '\n\r:')
assert pwd.getpwnam('tablet').pw_uid==10000
for group in expected-{'quickUser'}:grp.getgrnam(group)
existing=[p for p in pwd.getpwall() if p.pw_name==data['username'] or p.pw_uid==data['uid']]
if existing:
    assert len(existing)==1 and existing[0].pw_name==data['username']
    assert existing[0].pw_uid==data['uid'] and existing[0].pw_gid==data['gid']
else:
    assert not any(g.gr_name=='quickUser' or g.gr_gid==10001 for g in grp.getgrall())
    assert not Path(data['home']).exists()
    subprocess.run(['addgroup','-g','10001',data['username']],check=True,capture_output=True)
    subprocess.run(['useradd','-u','10001','-g',data['username'],'-G',','.join(sorted(expected-{'quickUser'})),
                    '-m','-s',data['shell'],'-c',data['gecos'],data['username']],check=True,capture_output=True)
    result=subprocess.run(['chpasswd','-e'],input=data['username']+':'+secret+'\n',text=True,capture_output=True)
    if result.returncode:
        raise RuntimeError('Encrypted-password restore failed: '+result.stderr.replace(secret,'[redacted]'))
user=pwd.getpwnam(data['username'])
assert user.pw_uid==user.pw_gid==10001 and user.pw_dir==data['home']
assert {grp.getgrgid(g).gr_name for g in os.getgrouplist(user.pw_name,user.pw_gid)}==expected
rows=[line.split(':') for line in Path('/etc/shadow').read_text().splitlines() if line.startswith(user.pw_name+':')]
assert len(rows)==1 and rows[0][1]==secret
marker=Path('/var/lib/gta4l-ui-qc/restored-account.json')
marker.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
marker.write_text(json.dumps({'username':user.pw_name,'uid':user.pw_uid,'groups':sorted(expected),
                              'same_password_restored':True,'fresh_ui_home_defaults':True},indent=2)+'\n')
marker.chmod(0o600)
source.unlink()
os.sync()
print('REQUESTED_QC_ACCOUNT_RESTORED; password retained; fresh UI home defaults')
