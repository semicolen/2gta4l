#!/usr/bin/env python3
"""Assemble isolated desktop rootfs/OrangeFox candidates locally in WSL."""
from pathlib import Path
import argparse,configparser,hashlib,json,os,re,shutil,struct,subprocess,sys,tarfile
workspace=Path(__file__).resolve().parents[1]
base=Path('/home/pmos/sm-t505-port')
tools=workspace/'tools'
parser=argparse.ArgumentParser()
parser.add_argument('--ui',choices=('xfce4','plasma-mobile','plasma-desktop','gnome-mobile','gnome','sxmo-de-sway'))
parser.add_argument('--resume',action='store_true')
args=parser.parse_args()
profiles=json.loads((workspace/'ui-profiles/profiles.json').read_text())
selected=[args.ui] if args.ui else list(profiles)
login=(workspace/'artifacts/initial-login.txt').read_text()
password=re.search(r'^Password: (.+)$',login,re.M)[1]
assert re.search(r'^User: tablet$',login,re.M)
output=workspace/'artifacts/ui-builds'
output.mkdir(parents=True,exist_ok=True)
logs=workspace/'logs/ui-builds';logs.mkdir(parents=True,exist_ok=True)
stable=workspace/'artifacts/boot-current.img'
boot=json.loads((workspace/'artifacts/boot-current-verification.json').read_text())
assert hashlib.sha256(stable.read_bytes()).hexdigest()==boot['sha256']=='4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663'
manifest=json.loads((workspace/'artifacts/bluetooth-fix-verification.json').read_text())['modules_sha256']
assert len(manifest)==37
def step(ui,title,command):
    print(ui+': '+title,flush=True)
    with (logs/(ui+'-'+title.replace(' ','-')+'.log')).open('wb') as log:
        result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError(ui+': '+title+' failed (exit '+str(result.returncode)+'); see logs/ui-builds')
def ready(path):
    if not path.exists():return False
    data=json.loads(path.read_text())
    if data.get('packaging_schema')!=2:return False
    zip_path=output/data['package']
    if not zip_path.is_file() or zip_path.stat().st_size!=data['bytes']:return False
    with zip_path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()==data['sha256']
step('shared','refresh ARM64 repository indexes',['bash',str(tools/'pmb.sh'),'update','--arch','aarch64'])
step('shared','initialize ARM64 tooling',['sh',str(tools/'ensure-wsl-arm64-emulation.sh')])
step('shared','build OpenRC Plasma profiles',['bash',str(tools/'build-ui-profiles.sh')])
step('shared','unmount baseline build tools',['bash',str(tools/'pmb.sh'),'shutdown'])
mounts=[line.split()[4] for line in Path('/proc/self/mountinfo').read_text().splitlines()]
assert not any(path.startswith(str(base/'work')+'/chroot_') for path in mounts),'Baseline build tools still have active mounts'
for ui in selected:
    report_path=output/(ui+'-verification.json')
    if args.resume and ready(report_path):print(ui+': completed candidate verified; skipping',flush=True);continue
    profile=profiles[ui]
    work=base/'ui-work'/ui
    work.mkdir(parents=True,exist_ok=True)
    # Copied chroots use the same pmbootstrap format as the baseline workdir.
    shutil.copyfile(base/'work/version',work/'version')
    metadata=configparser.ConfigParser()
    metadata.read(base/'work/workdir.cfg')
    for section in metadata.sections():
        for key in list(metadata[section]):
            if key.startswith('rootfs_'):del metadata[section][key]
    if not (work/'workdir.cfg').exists():
        with (work/'workdir.cfg').open('w') as stream:metadata.write(stream)
    shutil.copy2(base/'work/apk.static',work/'apk.static')
    for name in ('packages','cache_distfiles','cache_apk_aarch64','cache_apk_x86_64','cache_git','cache_http'):
        target=work/name
        if not target.exists():target.symlink_to(base/'work'/name,target_is_directory=True)
        assert target.is_symlink() and target.resolve()==(base/'work'/name).resolve()
    for name in ('config_abuild','config_apk_keys'):
        if not (work/name).exists():shutil.copytree(base/'work'/name,work/name)
        # abuild runs as the unprivileged pmos user inside copied tool chroots.
        for source in [base/'work'/name,*sorted((base/'work'/name).rglob('*'))]:
            target=work/name/source.relative_to(base/'work'/name)
            metadata=source.stat()
            os.chown(target,metadata.st_uid,metadata.st_gid)
    # Reuse local tools/signing keys without reusing another UI's rootfs.
    for name in ('chroot_native','chroot_buildroot_aarch64'):
        if not (work/name).exists():
            step(ui,'copy local build tools',['cp','-a','--reflink=auto',str(base/'work'/name),str(work/name)])
    cfg=configparser.ConfigParser()
    cfg.read(workspace/'tools/pmbootstrap.cfg')
    cfg['pmbootstrap']['ui']=ui
    cfg['pmbootstrap']['work']=str(work)
    cfg['pmbootstrap']['service_manager']='openrc'
    cfg['pmbootstrap']['ui_extras']='False'
    cfg['pmbootstrap']['extra_packages']+=',device-samsung-gta4l-nonfree-firmware,postmarketos-base-ui-audio-backend-pulseaudio'
    cfg['providers']['postmarketos-base-ui-audio-backend']='postmarketos-base-ui-audio-backend-pulseaudio'
    config=output/(ui+'-pmbootstrap.cfg')
    with config.open('w') as stream:cfg.write(stream)
    pmb=[sys.executable,str(base/'sources/pmbootstrap/pmbootstrap.py'),'--as-root','-c',str(config)]
    report_path.unlink(missing_ok=True)
    step(ui,'clean up previous mounts',pmb+['shutdown'])
    step(ui,'initialize ARM64 emulation',['sh',str(tools/'ensure-wsl-arm64-emulation.sh')])
    step(ui,'create root filesystem',pmb+['install','--no-image','--password',password])
    root=work/'chroot_rootfs_samsung-gta4l'
    # Preserve the demonstrated graphics, modem, camera and speaker stack.
    records={}
    for section in (root/'lib/apk/db/installed').read_text().split('\n\n'):
        values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
        if 'P' in values:records[values['P']]=values['V']
    assert records['device-samsung-gta4l']=='1-r23',records.get('device-samsung-gta4l')
    assert records.get('alsa-ucm-gta4l-pulseaudio')=='1.0-r3'
    assert profile['ui_package'] in records
    forbidden=[name for name in records if name.startswith('postmarketos-ui-') and name not in
               (profile['ui_package'],profile['ui_package']+'-openrc',profile['ui_package']+'-web')]
    assert not forbidden,forbidden
    assert 'pipewire-pulse' not in records,'The tested audio backend must own the PulseAudio socket'
    if ui!='xfce4':assert 'xfce4-screensaver' not in records
    group=(root/'etc/group').read_text()
    if 'tablet' not in next(line.split(':')[3].split(',') for line in group.splitlines() if line.startswith('video:')):
        step(ui,'grant camera access',['chroot',str(root),'addgroup','tablet','video'])
    overlays={}
    if profile['session_type']=='wayland':
        # This launcher controls Xrandr and belongs to the Xfce session only.
        launcher=root/'usr/share/applications/gta4l-rotation-lock.desktop'
        if 'OnlyShowIn=' not in launcher.read_text():
            launcher.write_text(launcher.read_text().rstrip()+'\nOnlyShowIn=XFCE;\n')
        overlays[str(launcher.relative_to(root))]=hashlib.sha256(launcher.read_bytes()).hexdigest()
        environment=(workspace/'ui-profiles/wayland-environment').read_text()
        if ui=='sxmo-de-sway':environment+=(workspace/'ui-profiles/sxmo-environment').read_text()
        env_path=root/'etc/environment'
        current=env_path.read_text()
        current=re.sub(r'\n# GTA4L_UI_RENDERING_BEGIN\n.*?# GTA4L_UI_RENDERING_END\n','\n',current,flags=re.S)
        env_path.write_text(current.rstrip()+'\n# GTA4L_UI_RENDERING_BEGIN\n'+environment+'# GTA4L_UI_RENDERING_END\n')
        values=[line for line in environment.splitlines() if line and not line.startswith('#')]
        script='#!/bin/sh\n'+'\n'.join('export '+line for line in values)+'\n'
        path=root/'etc/profile.d/80-gta4l-rendering.sh';path.write_text(script);overlays[str(path.relative_to(root))]=hashlib.sha256(path.read_bytes()).hexdigest()
        overlays['etc/environment']=hashlib.sha256(env_path.read_bytes()).hexdigest()
        if ui=='sxmo-de-sway':
            path=root/'etc/sway/config.d/80-gta4l-output.conf'
            path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(workspace/'ui-profiles/sxmo-output.conf',path)
            overlays[str(path.relative_to(root))]=hashlib.sha256(path.read_bytes()).hexdigest()
    root_report=output/(ui+'-rootfs-verification.json')
    step(ui,'verify root filesystem',[sys.executable,str(tools/'verify-rootfs.py'),'--root',str(root),'--ui',ui,'--report',str(root_report)])
    verification=json.loads(root_report.read_text())
    verification['ui_overlay_sha256']=overlays
    root_report.write_text(json.dumps(verification,indent=2)+'\n')
    for name,digest in manifest.items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name
    step(ui,'unmount build chroots',pmb+['shutdown'])
    mounts=[line.split()[4] for line in Path('/proc/self/mountinfo').read_text().splitlines()]
    assert not any(path.startswith(str(root)+'/') for path in mounts),'Rootfs still has active mounts'
    step(ui,'package tested boot',[sys.executable,str(tools/'package-ui-recovery.py'),'--ui',ui,'--root',str(root),'--root-report',str(root_report)])
    print(ui+': LOCAL_WSL_UI_CANDIDATE_COMPLETE',flush=True)
reports=[json.loads(path.read_text()) for path in sorted(output.glob('*-verification.json')) if path.name in [ui+'-verification.json' for ui in profiles]]
(output/'index.json').write_text(json.dumps({'device':'SM-T505','build_host':'WSL Ubuntu','profiles':reports},indent=2)+'\n')
(output/'SHA256SUMS').write_text(''.join(item['sha256']+'  '+item['package']+'\n' for item in reports))
if not args.ui:
    step('shared','verify all six build receipts',[sys.executable,str(tools/'finish-ui-builds.py')])
print('UI_CANDIDATE_BUILD_BATCH_COMPLETED',flush=True)
