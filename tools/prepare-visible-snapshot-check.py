#!/usr/bin/env python3
"""Reuse the already visible candidate window for the strict photo regression."""
from pathlib import Path
import ast
workspace=Path(__file__).resolve().parents[1]
text=(workspace/'diagnostics/ui-qc-snapshot-photo-stress.sh').read_text()
body=text.split("python3 - <<'PY'\n",1)[1].rsplit('\nPY',1)[0]
tree=ast.parse(body)
code=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='code' for t in n.targets))
prefix=body.split("for p in Path('/proc').iterdir():",1)[0]
ending='''
candidate=Path('/run/gta4l-snapshot-candidate/snapshot')
apps=[]
for p in Path('/proc').iterdir():
    try:
        if p.name.isdigit() and p.stat().st_uid==uid and (p/'exe').resolve()==candidate:apps.append(p)
    except (OSError,ProcessLookupError):pass
assert len(apps)==1,'Expected the visible candidate process'
old_mode=subprocess.check_output(['gsettings','get','org.gnome.Snapshot','capture-mode'],text=True,timeout=5,**identity).strip()
old_sound=subprocess.check_output(['gsettings','get','org.gnome.Snapshot','play-shutter-sound'],text=True,timeout=5,**identity).strip()
subprocess.run(['gsettings','set','org.gnome.Snapshot','capture-mode','picture'],check=True,timeout=5,**identity)
subprocess.run(['gsettings','set','org.gnome.Snapshot','play-shutter-sound','true'],check=True,timeout=5,**identity)
log=Path('/run/gta4l-snapshot-stress/snapshot.log');offset=log.stat().st_size
time.sleep(2)
try:
    probe=subprocess.run(['python3','-c',__CODE__],capture_output=True,text=True,timeout=45,**identity)
    print(probe.stdout,probe.stderr,flush=True)
finally:
    subprocess.run(['gsettings','set','org.gnome.Snapshot','capture-mode',old_mode],check=True,timeout=5,**identity)
    subprocess.run(['gsettings','set','org.gnome.Snapshot','play-shutter-sound',old_sound],check=True,timeout=5,**identity)
print('VISIBLE_CANDIDATE_STILL_RUNNING',apps[0].exists(),flush=True)
with log.open('rb') as stream:stream.seek(offset);print('VISIBLE_CAMERA_DIAGNOSTICS',stream.read(16000).decode(errors='replace'),flush=True)
assert probe.returncode==0 and apps[0].exists()
print('VISIBLE_CAMERA_EIGHT_SAVED_PHOTOS_WITH_SHUTTER_SOUND_PASSED',flush=True)
'''.replace('__CODE__',repr(code))
out=workspace/'artifacts/diagnostics/snapshot-visible-photo-check.sh'
out.write_text("#!/bin/sh\nset -eu\npython3 - <<'PY'\n"+prefix+ending+"\nPY\n",newline='\n')
print('VISIBLE_CANDIDATE_PHOTO_CHECK_PREPARED')
