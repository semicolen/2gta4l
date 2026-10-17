#!/usr/bin/env python3
"""Keep tested build artifacts while removing obsolete candidates from selection."""
from pathlib import Path
import hashlib
root=Path('/home/ark/sm-t505-port').resolve()
workspace=Path(__file__).resolve().parents[1]
repository=(root/'work/packages/edge/aarch64').resolve()
retired=(root/'diagnostics/retired-zink-apks').resolve()
assert repository.is_relative_to(root) and retired.is_relative_to(root)
retired.mkdir(parents=True,exist_ok=True)
for release in ('26.2.4-r0','26.0.8-r1','26.0.8-r2'):
    name='mesa-zink-kgsl-gta4l-'+release+'.apk'
    source=repository/name
    if not source.exists():continue
    saved=workspace/'artifacts/apks'/name
    assert saved.is_file(),'Preserved Windows build artifact missing: '+name
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    assert hashlib.sha256(saved.read_bytes()).hexdigest()==digest,'Archive differs: '+name
    target=retired/name
    assert source.resolve().is_relative_to(repository) and target.resolve().is_relative_to(retired)
    assert not target.exists(),'Inspect existing retired package: '+name
    source.rename(target)
    print('Preserved outside active repository:',name,digest)
