#!/usr/bin/env python3
"""Stage exact cached packages removed by the camera QC offline transaction."""
from pathlib import Path
import hashlib,json,shutil
workspace=Path(__file__).resolve().parents[1]
cache=Path('/home/ark/sm-t505-port/work/cache_apk_aarch64')
out=workspace/'artifacts/ui-qc/packages'
out.mkdir(parents=True,exist_ok=True)
names=('gcr','gcr-base','gcr-lang','gnome-keyring','gnome-keyring-pam',
       'gnome-keyring-lang','gnome-keyring-openrc')
records=[]
for name in names:
    version='3.41.2-r3' if name.startswith('gcr') else '51.1-r0'
    files=list(cache.glob(name+'-'+version+'.*.apk'))
    assert len(files)==1,(name,files)
    target=out/(name+'-'+version+'.apk')
    shutil.copyfile(files[0],target)
    records.append({'name':name,'version':version,'file':target.name,
                    'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
(out/'keyring-restore.json').write_text(json.dumps(records,indent=2)+'\n')
script=workspace/'diagnostics/ui-qc-restore-keyring.sh'
text='#!/bin/sh\nset -eu\nsha256sum -c - <<\'CHECKSUMS\'\n'
text+=''.join(row['sha256']+'  /tmp/gta4l-upload/'+row['file']+'\n' for row in records)
text+='CHECKSUMS\napk add --no-network '+ ' '.join('/tmp/gta4l-upload/'+row['file'] for row in records)+'\n'
text+='printf "KEYRING_EXACT_VERSIONS_RESTORED\\n"\n'
script.write_text(text)
print('Staged seven exact cached keyring packages with hashes')
