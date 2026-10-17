#!/usr/bin/env python3
"""Exercise QC account restoration in a disposable WSL overlay with fake data."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,tempfile

assert os.geteuid()==0
workspace=Path(__file__).resolve().parents[1]
lower=Path('/home/ark/sm-t505-port/ui-work/gnome/chroot_rootfs_samsung-gta4l')
assert (lower/'etc/passwd').is_file()
baseline={name:(lower/name).read_bytes() for name in ('etc/passwd','etc/shadow','etc/group','lib/apk/db/installed')}
with tempfile.TemporaryDirectory(prefix='gta4l-account-restore-test-',dir='/tmp') as directory:
    base=Path(directory).resolve()
    assert base.parent==Path('/tmp') and base.name.startswith('gta4l-account-restore-test-')
    upper=base/'upper';work=base/'work';root=base/'root'
    for path in (upper,work,root):path.mkdir()
    subprocess.run(['mount','-t','overlay','overlay','-o',f'lowerdir={lower},upperdir={upper},workdir={work}',str(root)],check=True)
    try:
        private=root/'tmp/gta4l-qc-account';private.mkdir(mode=0o700)
        shutil.copyfile(workspace/'diagnostics/ui-qc-restore-account.py',private/'restore.py')
        fake={'username':'quickUser','uid':10001,'gid':10001,'home':'/home/quickUser','shell':'/bin/ash',
              'gecos':'Disposable QC fixture','groups':['quickUser','wheel','audio','video','netdev','plugdev'],
              'encrypted_password':'$6$gta4lfixture$'+'a'*86}
        subprocess.run(['mount','--bind','/dev',str(root/'dev')],check=True)
        try:
            for attempt in (1,2):
                (private/'account.json').write_text(json.dumps(fake))
                result=subprocess.run(['chroot',str(root),'/usr/bin/python3','/tmp/gta4l-qc-account/restore.py',
                                       '/tmp/gta4l-qc-account/account.json'],capture_output=True,text=True,timeout=45)
                assert result.returncode==0,(attempt,result.stdout,result.stderr)
                assert 'REQUESTED_QC_ACCOUNT_RESTORED' in result.stdout
                assert not (private/'account.json').exists()
                print('PASS restore attempt',attempt,flush=True)
        finally:
            subprocess.run(['umount',str(root/'dev')],check=True)
        assert (root/'home/quickUser').stat().st_uid==10001
        before=baseline['etc/shadow'].decode().splitlines()
        after=(root/'etc/shadow').read_text().splitlines()
        assert [line for line in after if not line.startswith('quickUser:')]==before
        assert (root/'lib/apk/db/installed').read_bytes()==baseline['lib/apk/db/installed']
    finally:
        subprocess.run(['umount',str(root)],check=True)
assert all((lower/name).read_bytes()==data for name,data in baseline.items())
print('DISPOSABLE_WSL_ACCOUNT_RESTORE_PASS; lower image and other account credentials unchanged')
