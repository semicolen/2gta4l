#!/usr/bin/env python3
"""Restore the requested private test account after a verified clean install."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tarfile,tempfile

workspace=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--serial',required=True)
parser.add_argument('--ui',choices=('gnome','gnome-mobile'),required=True)
parser.add_argument('--verify-backup-only',action='store_true')
args=parser.parse_args()
backup=workspace/'artifacts/backups/quickUser-before-ui-r13.tar.gz'
receipt=json.loads(backup.with_suffix('.json').read_text())
assert receipt['device_hash_matches'] and receipt['username']=='quickUser'
assert backup.stat().st_size==receipt['bytes']
assert hashlib.sha256(backup.read_bytes()).hexdigest()==receipt['sha256']
with tarfile.open(backup,'r:gz') as archive:
    member=archive.getmember('account.json')
    assert member.isfile() and member.size<4096
    private_data=archive.extractfile(member).read()
data=json.loads(private_data)
assert data['username']=='quickUser' and data['uid']==10001
assert set(data['groups'])=={'quickUser','wheel','audio','video','netdev','plugdev'}
helper=workspace/'diagnostics/ui-qc-restore-account.py'
assert receipt['disposable_wsl_restore_test_passed'] and receipt['idempotent_restore_test_passed']
assert hashlib.sha256(helper.read_bytes()).hexdigest()==receipt['restore_helper_sha256']
if args.verify_backup_only:
    print('PRIVATE_ACCOUNT_BACKUP_AND_TESTED_RESTORE_HELPER_VERIFIED; credentials not printed')
    raise SystemExit(0)
ui_dir=workspace/'evidence/ui-qc'/args.ui
out=ui_dir/(ui_dir/'latest-attempt.txt').read_text().strip()
assert out.resolve().parent==ui_dir.resolve()
installation_path=out/'installation.json'
installation=json.loads(installation_path.read_text())
assert installation['ui']==args.ui and installation['installer_completed']
assert installation['boot_readback_matches'] and installation['recovery_unchanged']
adb=['adb','-s',args.serial]
def run(*args,timeout=30):
    return subprocess.run(adb+list(args),check=True,capture_output=True,timeout=timeout).stdout
assert run('get-state').strip()==b'recovery'
assert run('shell','getprop','ro.product.device').strip()==b'gta4l'
assert run('shell','getprop','ro.bootloader').strip().startswith(b'T505')
root='/tmp/postmarketos/chroot/mnt/pmOS'
assert b'tablet:x:10000:' in run('exec-out','cat',root+'/etc/passwd')
remote=root+'/tmp/gta4l-qc-account'
run('shell','mkdir','-m','700',remote)
private_root=workspace/'artifacts/private-qc'
private_root.mkdir(exist_ok=True)
try:
    with tempfile.TemporaryDirectory(prefix='account-restore-',dir=private_root) as directory:
        local=Path(directory).resolve()
        assert local.is_relative_to(private_root.resolve())
        account=local/'account.json';account.write_bytes(private_data)
        run('push',str(account),remote+'/account.json')
        run('push',str(helper),remote+'/restore.py')
    run('shell','chmod','600',remote+'/account.json',remote+'/restore.py')
    run('shell','mount','--bind','/dev',root+'/dev')
    try:
        result=run('shell','chroot',root,'/usr/bin/python3','/tmp/gta4l-qc-account/restore.py',
                   '/tmp/gta4l-qc-account/account.json',timeout=60)
    finally:
        run('shell','umount',root+'/dev')
    assert b'REQUESTED_QC_ACCOUNT_RESTORED' in result
    (out/'account-restored.txt').write_bytes(result)
    installation.update(requested_qc_account_restored=True,same_account_password_restored=True,
                        qc_account_home_uses_fresh_ui_defaults=True,
                        private_account_backup_sha256=receipt['sha256'])
    installation_path.write_text(json.dumps(installation,indent=2)+'\n')
finally:
    run('shell','rm','-f',remote+'/account.json',remote+'/restore.py')
    run('shell','rmdir',remote)
print('Requested QC account restored through recovery; password not printed')
