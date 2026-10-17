#!/usr/bin/env python3
"""Copy authored sources into the dedicated, clean publication checkout."""
from pathlib import Path
import re,shutil,subprocess
workspace=Path(__file__).resolve().parents[1]
destination=workspace/'.publication/2gta4l'
def git(*args):return subprocess.check_output(['git','-C',str(destination),*args],text=True).strip()
assert git('branch','--show-current')=='downstream'
assert not git('status','--porcelain'),'Publication checkout must start clean'
assert git('rev-list','--left-right','--count','HEAD...origin/downstream').split()==['0','0']
notice='This repo is not eligible to be merged to Nura (Formerly known as postmarket os) due to the ai policy seen [here](https://docs.nura.eco/policies-and-processes/development/ai-policy.html).\nDo not intentionally upload it, merge it or contribute code with the fact stated.'
assert notice in (destination/'README.md').read_text() and notice in (workspace/'README.md').read_text()
login=(workspace/'artifacts/initial-login.txt').read_text()
secret=re.search(r'^Password: (.+)$',login,re.M)[1]
assert len(secret)>=8
files=[p for p in workspace.glob('*.md') if p.name!='AGENTS.md']+[workspace/'.gitignore']
for directory in ('port','tools','ui-profiles','diagnostics'):
    files.extend(p for p in (workspace/directory).rglob('*') if p.is_file() and not p.is_symlink())
excluded=('.tar.gz','.tar.xz','.tar.zst','.zip','.apk','.img','.dtb','.bin','.so','.exe','.png','.jpg','.jpeg','.mp4','.webm','.wav','.raw','.pyc')
copied=0;skipped=0
for source in sorted(set(files)):
    relative=source.relative_to(workspace)
    if '__pycache__' in relative.parts or source.name.endswith(excluded) or source.stat().st_size>8*1024*1024:
        skipped+=1;continue
    data=source.read_bytes()
    if b'\0' in data:skipped+=1;continue
    try:text=data.decode('utf-8')
    except UnicodeDecodeError:skipped+=1;continue
    assert secret not in text,'Login credential found in source: '+str(relative)
    assert not re.search(r'\$(?:[156]|y)\$[A-Za-z0-9./$]{24,}',text),'Password hash found in source: '+str(relative)
    assert not re.search(r'-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----\s+[A-Za-z0-9+/]{32}',text),'Private key found in source: '+str(relative)
    target=destination/relative
    assert target.resolve().is_relative_to(destination.resolve())
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target);copied+=1
assert notice in (destination/'README.md').read_text()
print('PUBLICATION_AUTHORED_TEXT_FILES_COPIED',copied,'non-source/cache files skipped',skipped)
print('CREDENTIAL_SCAN_AND_EXISTING_REPOSITORY_NOTICE_PASSED')
