#!/usr/bin/env python3
"""Install a guarded kernel ZIP through OrangeFox and verify both partitions."""
from pathlib import Path
import argparse,hashlib,json,subprocess
from datetime import datetime,timezone

workspace=Path(__file__).resolve().parents[1]
artifacts=workspace/'artifacts'
parser=argparse.ArgumentParser()
parser.add_argument('--candidate',choices=('gnome','file-access'),default='gnome')
args=parser.parse_args()
tag='file-access-kernel-fix' if args.candidate=='file-access' else 'gnome-kernel-fix'
manifest=json.loads((artifacts/f'{tag}-verification.json').read_text())
backup=json.loads((artifacts/'backups/ui-qc-working-system/manifest.json').read_text())
assert backup['verified_complete'] and backup['serial']=='R9WNC1QG0LJ'
package=artifacts/f'postmarketOS-SM-T505-OrangeFox-{tag}.zip'
assert hashlib.sha256(package.read_bytes()).hexdigest()==manifest['package_sha256']
out=workspace/'evidence/ui-qc/gnome'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'+tag)
out.mkdir(parents=True,exist_ok=False)
adb=['adb','-s',backup['serial']]
def run(*args,timeout=30):
    return subprocess.run(adb+list(args),capture_output=True,check=True,timeout=timeout).stdout
def query(*args,timeout=30):return run('shell',*args,timeout=timeout).decode().strip()
assert run('get-state').decode().strip()=='recovery'
assert query('id','-u')=='0'
assert query('getprop','ro.product.device')=='gta4l'
assert query('getprop','ro.bootloader').startswith('T505')
assert query('readlink','-f','/dev/block/by-name/boot')=='/dev/block/mmcblk0p69'
assert query('blockdev','--getsize64','/dev/block/by-name/boot')=='100663296'
assert int(query('cat','/sys/class/power_supply/battery/capacity'))>=25
def recovery_hash():
    return query('sha256sum','/dev/block/by-name/recovery',timeout=90).split()[0]
expected_recovery=backup['partitions']['recovery']['sha256']
assert recovery_hash()==expected_recovery
before=run('exec-out','head','-c',str(manifest['expected_installed_boot_bytes']),'/dev/block/by-name/boot',timeout=60)
assert len(before)==manifest['expected_installed_boot_bytes']
assert hashlib.sha256(before).hexdigest()==manifest['expected_installed_boot_sha256']
remote=f'/tmp/gta4l-{tag}.zip'
run('push',str(package),remote,timeout=90)
assert query('sha256sum',remote).split()[0]==manifest['package_sha256']
result=run('shell','twrp','install',remote,timeout=180)
(out/'orangefox-install.txt').write_bytes(result)
assert b'GNOME kernel fix boot verified.' in result,'Inspect OrangeFox log before reboot'
readback=run('exec-out','head','-c',str(manifest['boot_bytes']),'/dev/block/by-name/boot',timeout=60)
assert len(readback)==manifest['boot_bytes']
actual=hashlib.sha256(readback).hexdigest()
assert actual==manifest['boot_sha256']
assert recovery_hash()==expected_recovery
report={'installed_through':'OrangeFox twrp install','boot_sha256':actual,'boot_readback_matches':True,
        'recovery_unchanged':True,'formats_userdata':False,'kernel_build_version':manifest['kernel_build_version'],
        'runtime_verified':False,'completed_at':datetime.now(timezone.utc).isoformat()}
(out/'installation.json').write_text(json.dumps(report,indent=2)+'\n')
print(manifest['kernel_build_version']+' BOOT_READBACK_AND_RECOVERY_VERIFIED; remains in OrangeFox',flush=True)
print('Evidence: '+str(out),flush=True)
