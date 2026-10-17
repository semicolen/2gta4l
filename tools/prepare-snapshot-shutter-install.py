#!/usr/bin/env python3
"""Audit the patched native Camera package and prepare a guarded app update."""
from pathlib import Path
import hashlib,json,struct,tarfile
workspace=Path(__file__).resolve().parents[1]
records=[]
def allocated_sections(elf):
    assert elf[:6]==b'\x7fELF\x02\x01'
    offset=struct.unpack_from('<Q',elf,40)[0]
    size,count,strings=struct.unpack_from('<HHH',elf,58)
    assert size==64 and offset+size*count<=len(elf) and strings<count
    sections=[struct.unpack_from('<IIQQQQIIQQ',elf,offset+size*n) for n in range(count)]
    string_table=sections[strings];names=elf[string_table[4]:string_table[4]+string_table[5]]
    result={}
    for name,kind,flags,address,start,length,*unused in sections:
        if not flags&2:continue
        title=names[name:].split(b'\0',1)[0].decode()
        assert kind==8 or start+length<=len(elf)
        data=b'' if kind==8 else elf[start:start+length]
        result[title]=(kind,flags,address,length,hashlib.sha256(data).hexdigest())
    return result
for name in ('snapshot','snapshot-lang'):
    path=workspace/'artifacts/apks'/f'{name}-51.0-r1.apk'
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        files={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    assert f'pkgname = {name}\n'.encode() in files['.PKGINFO'] and b'pkgver = 51.0-r1\n' in files['.PKGINFO']
    assert any(n.startswith('.SIGN.') for n in files)
    record={'name':name,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    if name=='snapshot':
        executables=[(name,data) for name,data in files.items() if name in ('usr/bin/snapshot','usr/sbin/snapshot')]
        assert len(executables)==1
        elf=executables[0][1];assert elf[:4]==b'\x7fELF' and int.from_bytes(elf[18:20],'little')==183
        assert b'.dep-v0\0' in elf,'Cargo audit dependency metadata missing'
        candidate=(workspace/'artifacts/snapshot-shutter-r1-candidate').read_bytes()
        assert allocated_sections(candidate)==allocated_sections(elf),'Packaged executable differs from hardware-tested code/data'
        record.update(executable=executables[0][0],executable_sha256=hashlib.sha256(elf).hexdigest())
    records.append(record)
script='''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,signal,subprocess,time
records=json.loads('__RECORDS__')
def versions():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
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
'''.replace('__RECORDS__',json.dumps(records))
(workspace/'diagnostics/ui-qc-install-snapshot-shutter.sh').write_text(script,newline='\n')
(workspace/'artifacts/snapshot-shutter-r1-audit.json').write_text(json.dumps({'packages':records,'runtime_verified':False,'regression_without_shutter_sound_eight_actions_app_survived':True,'hardware_tested_candidate_allocated_code_and_data_identical':True,'candidate_eight_front_jpegs_with_shutter_sound_passed':True,'candidate_rear_photos_and_repeated_shutter_sound_user_passed':True,'upstream_cargo_test_passed':True,'upstream_unit_test_count':0},indent=2)+'\n')
print('SIGNED_ARM64_SNAPSHOT_SHUTTER_PACKAGE_AUDITED')
