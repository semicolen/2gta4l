#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,signal,subprocess,time
records=json.loads('[{"name": "snapshot", "file": "snapshot-51.0-r1.apk", "sha256": "c1cbef5972240aab417b04b60c6b3afc25c9a5bf439e01c42043657170d60501", "executable": "usr/bin/snapshot", "executable_sha256": "4976bc5d9810b3976424996b022c090454073c49d64fad088939787dce347362"}, {"name": "snapshot-lang", "file": "snapshot-lang-51.0-r1.apk", "sha256": "229943c48eed677dec62280672992f1045465f31d9f1b1f107aea96c7ec3cc10"}]')
def versions():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\n\n'):
        v=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in v:result[v['P']]=v['V']
    return result
before=versions();assert before['snapshot']=='51.0-r0'
records=[r for r in records if r['name'] in before]
assert all(before[r['name']]=='51.0-r0' for r in records)
def boot_hash():
    with open('/dev/mmcblk0p69','rb') as stream:return hashlib.sha256(stream.read(28938256)).hexdigest()
expected='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
assert boot_hash()==expected
paths=[]
for r in records:
    path=Path('/tmp/gta4l-upload')/r['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==r['sha256'];paths.append(str(path))
args=['apk','--no-network','--no-interactive','--no-scripts','add',*paths]
trial=subprocess.run([args[0],'--simulate',*args[1:]],capture_output=True,text=True,timeout=20)
print(trial.stdout,flush=True);assert trial.returncode==0,trial.stderr
for line in trial.stdout.splitlines():
    if any(word in line for word in ('Upgrading ','Downgrading ','Installing ','Replacing ','Purging ','Removing ')):
        assert any(r['name']+' (' in line for r in records),line
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'exe').resolve().name=='snapshot':os.kill(int(p.name),signal.SIGTERM)
    except (OSError,ProcessLookupError):pass
time.sleep(2)
subprocess.run(args,check=True,timeout=25)
after=versions()
for r in records:
    assert after.pop(r['name'])=='51.0-r1';before.pop(r['name'])
    if 'executable' in r:assert hashlib.sha256((Path('/')/r['executable']).read_bytes()).hexdigest()==r['executable_sha256']
assert after==before and boot_hash()==expected
print('SNAPSHOT_SHUTTER_R1_INSTALLED_OTHER_PACKAGES_AND_BOOT_UNCHANGED',flush=True)
PY
