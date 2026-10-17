#!/usr/bin/env python3
"""Audit the isolated Mesa APK and prepare a guarded diagnostic installation."""
from pathlib import Path, PurePosixPath
import gzip
import hashlib
import io
import json
import re
import tarfile

workspace = Path(__file__).resolve().parents[1]
recipe=(workspace/'port/mesa-zink-kgsl-gta4l/APKBUILD').read_text()
version=re.search(r'^pkgver=(.+)$',recipe,re.M).group(1)
revision=re.search(r'^pkgrel=(.+)$',recipe,re.M).group(1)
release=version+'-r'+revision
apk = workspace/'artifacts/apks'/('mesa-zink-kgsl-gta4l-'+release+'.apk')
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
with tarfile.open(fileobj=io.BytesIO(gzip.decompress(apk.read_bytes())), mode='r:', ignore_zeros=True) as archive:
    members = archive.getmembers()
    files = []
    metadata = None
    for member in members:
        name = member.name.removeprefix('./').rstrip('/')
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts, name
        if name == '.PKGINFO':
            metadata = archive.extractfile(member).read().decode()
        if name.startswith('.') or not name:
            continue
        if member.isdir() and name in ('usr','usr/lib','usr/bin','usr/lib/gta4l-zink'):
            continue
        assert name == 'usr/bin/gta4l-zink-run' or name.startswith('usr/lib/gta4l-zink/'), name
        if member.issym():
            assert not member.linkname.startswith('/') and '..' not in PurePosixPath(member.linkname).parts, (name,member.linkname)
        if member.isfile() or member.issym():
            files.append(name)
assert metadata and 'pkgname = mesa-zink-kgsl-gta4l' in metadata
providers={line.split(' = ',1)[1].split('=',1)[0] for line in metadata.splitlines() if line.startswith('provides = ')}
assert not providers.intersection({'so:libEGL.so.1','so:libGL.so.1','so:libGLESv1_CM.so.1','so:libGLESv2.so.2','so:libgbm.so.1'}),'Private libraries must not replace global Mesa providers'
assert 'usr/lib/gta4l-zink/lib/libgallium-'+version+'.so' in files
assert 'usr/lib/gta4l-zink/lib/dri/zink_dri.so' in files
assert 'usr/bin/gta4l-zink-run' in files
out = workspace/'artifacts/gpu/zink-package-audit.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({'apk':apk.name,'sha256':digest,'files':files,'metadata':metadata},indent=2)+'\n')
script = r'''#!/bin/sh
set -eu
printf '%s\n' '__HASH__  /tmp/gta4l-upload/__APK__' | sha256sum -c -
python3 - <<'PY'
from pathlib import Path
import json,subprocess
def packages():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in values:result[values['P']]=values['V']
    return result
before=packages()
assert before['mesa-vulkan-kgsl-gta4l']=='26.2.4-r0'
retain=['mesa','mesa-dri-gallium','mesa-egl','mesa-gl','mesa-gles','mesa-gbm',
        'gnome-keyring','gnome-keyring-pam','gnome-keyring-openrc','gnome-keyring-lang',
        'gcr','gcr-base','gcr-lang']
retain=[name for name in retain if name in before]
assert all(name in before for name in ('mesa-dri-gallium','mesa-egl','mesa-gles','mesa-gbm'))
args=['apk','add','--no-network','/tmp/gta4l-upload/__APK__']+retain
trial=subprocess.run(args[:2]+['--simulate']+args[2:],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
print(trial.stdout,flush=True)
assert trial.returncode==0,'Offline dependency resolution failed; no packages changed'
assert not any(word in trial.stdout for word in ('Purging','Removing')),'Unexpected package removal; no packages changed'
for line in trial.stdout.splitlines():
    if 'Upgrading' in line or 'Downgrading' in line:
        assert 'mesa-zink-kgsl-gta4l (' in line,'Unexpected package change; no packages changed'
backup=Path('/root/gta4l-gpu-qc-backup')
backup.mkdir(mode=0o700,exist_ok=True)
(backup/'installed-before-zink-__RELEASE__.json').write_text(json.dumps(before,indent=2)+'\n')
(backup/'world-before-zink-__RELEASE__').write_bytes(Path('/etc/apk/world').read_bytes())
subprocess.run(args,check=True)
after=packages()
assert all(name=='mesa-zink-kgsl-gta4l' or after.get(name)==version for name,version in before.items()),'An existing system package changed unexpectedly'
assert after['mesa-zink-kgsl-gta4l']=='__RELEASE__'
print('Only the isolated Zink package was installed; existing package versions retained',flush=True)
PY
echo ZINK_ISOLATED_INSTALL_COMPLETE
'''
(workspace/'diagnostics/ui-qc-install-zink.sh').write_text(script.replace('__HASH__',digest).replace('__APK__',apk.name).replace('__RELEASE__',release),newline='\n')
print('Audited isolated Mesa payload:',len(files),'files, SHA256',digest)
print(metadata)
