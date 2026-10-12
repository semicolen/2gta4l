#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import subprocess
import re
import shutil

root = Path('/home/pmos/sm-t505-port')
workspace = Path('/mnt/c/postmarketOS-gta4l')
report = {'device': 'SM-T505', 'stock_version': 'T505XXS8CXG1',
          'kernel_commit': '381a5549ee66fa751f632ee0840f5631274209ee',
          'runtime_verified': False, 'build_host': 'WSL Ubuntu', 'sources': {}}
for name in ['base-port', 'orangefox', 'pmbootstrap', 'pmaports', 'boot-deploy']:
    folder = root / 'sources' / name
    report['sources'][name] = {
        'commit': subprocess.check_output(['git', '-c', f'safe.directory={folder}', '-C', str(folder), 'rev-parse', 'HEAD'], text=True).strip(),
        'url': subprocess.check_output(['git', '-c', f'safe.directory={folder}', '-C', str(folder), 'remote', 'get-url', 'origin'], text=True).strip(),
    }
fw = root / 'firmware-stage/lib/firmware/postmarketos'
report['firmware'] = {str(f.relative_to(fw)): hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(fw.rglob('*')) if f.is_file()}
report['local_sources'] = {str(f.relative_to(workspace)): hashlib.sha256(f.read_bytes()).hexdigest()
                           for folder in ['port', 'recovery'] for f in sorted((workspace / folder).rglob('*')) if f.is_file()}
report['compiler'] = subprocess.check_output(['chroot', str(root / 'work/chroot_native'), 'clang', '--version'], text=True).strip()
report['packages'] = {}
destination = workspace / 'artifacts/apks'
destination.mkdir(parents=True, exist_ok=True)
for package in (workspace / 'port').iterdir():
    apkbuild = (package / 'APKBUILD').read_text()
    pkgver = re.search(r'^pkgver=(\S+)$', apkbuild, re.M)[1]
    pkgrel = re.search(r'^pkgrel=(\d+)$', apkbuild, re.M)[1]
    pattern = f'{package.name}*{pkgver}-r{pkgrel}.apk'
    files = list((root / 'work/packages/edge/aarch64').glob(pattern))
    assert any(f.name == f'{package.name}-{pkgver}-r{pkgrel}.apk' for f in files), package.name
    for f in files:
        shutil.copyfile(f, destination / f.name)
        report['packages'][f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
(workspace / 'artifacts/source-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('Recorded', len(report['firmware']), 'firmware files,', len(report['sources']), 'source revisions and', len(report['packages']), 'local APKs')
