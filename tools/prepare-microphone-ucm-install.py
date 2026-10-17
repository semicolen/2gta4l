#!/usr/bin/env python3
"""Audit the microphone packages and generate an internal-card-only update."""
from pathlib import Path
import hashlib,json,tarfile
workspace=Path(__file__).resolve().parents[1]
records=[]
for name in ('alsa-ucm-gta4l','alsa-ucm-gta4l-pulseaudio'):
    path=workspace/'artifacts/apks'/f'{name}-1.0-r4.apk'
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        files={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    assert f'pkgname = {name}\n'.encode() in files['.PKGINFO'] and b'pkgver = 1.0-r4\n' in files['.PKGINFO']
    expected={'usr/share/alsa/ucm2/Qualcomm/gta4l/HiFi.conf':'HiFi.conf','usr/share/alsa/ucm2/Qualcomm/gta4l/gta4l.conf':'gta4l.conf'} if name=='alsa-ucm-gta4l' else {'etc/pulse/default.pa.d/90-gta4l-audio.pa':'90-gta4l-audio.pa','usr/lib/udev/rules.d/90-gta4l-audio.rules':'90-gta4l-audio.rules'}
    for target,source in expected.items():assert files[target]==(workspace/'port/alsa-ucm-gta4l'/source).read_bytes()
    records.append({'name':name,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
script='''#!/bin/sh
set -eu
python3 - <<'PY'
from pathlib import Path
import hashlib,json,os,pwd,subprocess,time,shlex
assert os.geteuid()==0
records=json.loads('__RECORDS__')
def versions():
    result={}
    for section in Path('/lib/apk/db/installed').read_text().split('\\n\\n'):
        v=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in v:result[v['P']]=v['V']
    return result
before=versions()
assert all(before[r['name']] in ('1.0-r3','1.0-r4') for r in records)
def boot_hash():
    with open('/dev/mmcblk0p69','rb') as stream:return hashlib.sha256(stream.read(28938256)).hexdigest()
assert boot_hash()=='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
shell=next(p for p in Path('/proc').iterdir() if p.name.isdigit() and p.stat().st_uid>=10000 and (p/'comm').read_text().strip()=='gnome-shell')
uid=shell.stat().st_uid;user=pwd.getpwuid(uid)
env=dict(item.decode().split('=',1) for item in (shell/'environ').read_bytes().split(b'\\0') if b'=' in item)
env.update(HOME=user.pw_dir,USER=user.pw_name,XDG_RUNTIME_DIR=f'/run/user/{uid}',LC_ALL='C',LANG='C')
identity=dict(env=env,user=uid,group=user.pw_gid,extra_groups=os.getgrouplist(user.pw_name,user.pw_gid))
def pactl(*args):return subprocess.check_output(['pactl',*args],text=True,timeout=10,**identity)
cards=json.loads(pactl('-f','json','list','cards'))
run=Path('/run/gta4l-microphone-install');run.mkdir(mode=0o700,exist_ok=True)
assert not run.is_symlink() and run.stat().st_uid==0
card=next((c for c in cards if c['properties'].get('alsa.card')=='0'),None)
loaded=card is not None
if loaded:
    modules=json.loads(pactl('-f','json','list','modules'))
    row=next(line.split('\\t',3) for line in pactl('list','short','modules').splitlines() if line.split('\\t',1)[0]==str(card['owner_module']))
    assert row[1]=='module-alsa-card'
    module=next(m for m in modules if m['name']==row[1] and m['argument']==row[2]);module['index']=int(card['owner_module'])
    old_source=pactl('get-default-source').strip()
    (run/'pulse-before.json').write_text(json.dumps({'card':card,'module':module,'default_source':old_source}));(run/'pulse-before.json').chmod(0o600)
else:
    saved=json.loads((run/'pulse-before.json').read_text());card=saved['card'];module=saved['module'];old_source=saved['default_source']
assert module['name']=='module-alsa-card'
paths=[]
for r in records:
    path=Path('/tmp/gta4l-upload')/r['file'];assert hashlib.sha256(path.read_bytes()).hexdigest()==r['sha256'];paths.append(str(path))
args=['apk','--no-network','--no-interactive','--no-scripts','add',*paths]
trial=subprocess.run([args[0],'--simulate',*args[1:]],capture_output=True,text=True,timeout=20)
print(trial.stdout,flush=True);assert trial.returncode==0,trial.stderr
for line in trial.stdout.splitlines():
    if any(word in line for word in ('Upgrading ','Downgrading ','Installing ','Purging ','Removing ')):
        assert any(r['name']+' (' in line for r in records),line
subprocess.run(args,check=True,timeout=25)
after=versions()
for r in records:assert after.pop(r['name'])=='1.0-r4';before.pop(r['name'])
assert after==before and boot_hash()=='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
if loaded:pactl('unload-module',str(module['index']))
new_index=pactl('load-module',module['name'],*shlex.split(module['argument'])).strip()
time.sleep(3)
sources=json.loads(pactl('-f','json','list','sources'))
physical=[s for s in sources if s.get('properties',{}).get('alsa.card')=='0' and s['name'].startswith('alsa_input.') and not s['name'].endswith('.monitor')]
print('INTERNAL_SOURCES',[(s['name'],s['sample_specification'],s['mute']) for s in sources if s.get('properties',{}).get('alsa.card')=='0'],flush=True)
assert len(physical)==1,'Expected one physical internal microphone'
if old_source.endswith('.monitor') and 'alsa_output' in old_source:
    pactl('set-default-source',physical[0]['name'])
print('DEFAULT_CAPTURE_SOURCE',pactl('get-default-source').strip(),flush=True)
print('MICROPHONE_UCM_R4_INSTALLED_ONLY_INTERNAL_CARD_RELOADED',new_index,flush=True)
PY
'''.replace('__RECORDS__',json.dumps(records))
(workspace/'diagnostics/ui-qc-install-microphone-ucm.sh').write_text(script,newline='\n')
(workspace/'artifacts/microphone-ucm-r4-audit.json').write_text(json.dumps({'packages':records,'matching_source_verified':True,'acoustic_route_verified':True,'desktop_capture_verified':False,'video_audio_verified':False,'reboot_verified':False},indent=2)+'\n')
print('MICROPHONE_UCM_PACKAGES_AUDITED')
