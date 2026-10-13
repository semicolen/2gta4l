#!/usr/bin/env python3
"""Package one unmounted local UI rootfs with the tested kernel #9 boot."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,struct,subprocess,sys,tarfile,tempfile,zipfile
workspace=Path(__file__).resolve().parents[1]
base=Path('/home/pmos/sm-t505-port')
parser=argparse.ArgumentParser()
parser.add_argument('--ui',required=True)
parser.add_argument('--root',type=Path,required=True)
parser.add_argument('--root-report',type=Path,required=True)
args=parser.parse_args()
profiles=json.loads((workspace/'ui-profiles/profiles.json').read_text())
assert args.ui in profiles
root=args.root.resolve()
assert root.is_relative_to(base/'ui-work') and root.name=='chroot_rootfs_samsung-gta4l'
mounts=[line.split()[4] for line in Path('/proc/self/mountinfo').read_text().splitlines()]
assert not any(path==str(root) or path.startswith(str(root)+'/') for path in mounts)
artifacts=workspace/'artifacts/ui-builds'
stable=(workspace/'artifacts/boot-current.img').read_bytes()
boot_hash=hashlib.sha256(stable).hexdigest()
assert boot_hash=='4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663'
assert stable[:8]==b'ANDROID!' and struct.unpack_from('<I',stable,40)[0]==2
ks,_,rs=struct.unpack_from('<3I',stable,8)
page=struct.unpack_from('<I',stable,36)[0]
assert page==4096
align=lambda n:(n+page-1)//page*page
ramdisk_offset=page+align(ks)
dtb_offset=ramdisk_offset+align(rs)
dtb_size=struct.unpack_from('<I',stable,1648)[0]
assert (root/'boot/vmlinuz').read_bytes()==stable[page:page+ks]
assert (root/'boot/dtbs/qcom/gta4l.dtb').read_bytes()==stable[dtb_offset:dtb_offset+dtb_size]
modules=json.loads((workspace/'artifacts/bluetooth-fix-verification.json').read_text())['modules_sha256']
assert len(modules)==37
for name,digest in modules.items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name
(root/'boot/boot.img').write_bytes(stable)
(root/'boot/initramfs').write_bytes(stable[ramdisk_offset:ramdisk_offset+rs])
records={}
for section in (root/'lib/apk/db/installed').read_text().split('\n\n'):
    values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
    if 'P' in values:records[values['P']]=values['V']
expected={'device-samsung-gta4l':'1-r23','linux-samsung-gta4l':'4.19.300-r8',
          'camera-gta4l':'1.0-r2','gps-gta4l':'1.0-r3','alsa-ucm-gta4l':'1.0-r3',
          'alsa-ucm-gta4l-pulseaudio':'1.0-r3','modemmanager':'1.25.95_git20261005-r3'}
assert all(records.get(name)==version for name,version in expected.items())
assert profiles[args.ui]['ui_package'] in records
root_report=json.loads(args.root_report.read_text())
assert root_report['ui']==args.ui and root_report['checks_passed']
if profiles[args.ui]['session_type']=='wayland':
    launcher=root/'usr/share/applications/gta4l-rotation-lock.desktop'
    if 'OnlyShowIn=' not in launcher.read_text():
        launcher.write_text(launcher.read_text().rstrip()+'\nOnlyShowIn=XFCE;\n')
    overlay_paths=['etc/environment','etc/profile.d/80-gta4l-rendering.sh',
                   'usr/share/applications/gta4l-rotation-lock.desktop']
    settings=(workspace/'ui-profiles/wayland-environment').read_text()
    if args.ui=='sxmo-de-sway':
        settings+=(workspace/'ui-profiles/sxmo-environment').read_text()
        overlay_paths.append('etc/sway/config.d/80-gta4l-output.conf')
        assert (root/overlay_paths[-1]).read_bytes()==(workspace/'ui-profiles/sxmo-output.conf').read_bytes()
    for line in settings.splitlines():
        if line and not line.startswith('#'):
            assert line in (root/'etc/environment').read_text()
            assert 'export '+line in (root/'etc/profile.d/80-gta4l-rendering.sh').read_text()
    root_report['ui_overlay_sha256']={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in overlay_paths}
    args.root_report.write_text(json.dumps(root_report,indent=2)+'\n')
for name,digest in root_report.get('ui_overlay_sha256',{}).items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name

# pmbootstrap bind-mounts these keys while building. Its recovery exporter
# appends them separately; after shutdown a native tar must copy them first.
keys={}
for source in sorted((root.parent/'config_apk_keys').glob('*.pub')):
    target=root/'etc/apk/keys'/source.name
    shutil.copy2(source,target)
    target.chmod(0o644);os.chown(target,0,0)
    keys[str(target.relative_to(root))]=hashlib.sha256(target.read_bytes()).hexdigest()
assert keys,'Package-update trust keys missing'
template_ready=json.loads((workspace/'artifacts/current-recovery-source-ready.json').read_text())
template=Path(template_ready['source'])
with template.open('rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==template_ready['sha256']
output=artifacts/f'postmarketOS-SM-T505-OrangeFox-{args.ui}-r5.zip'
with tempfile.TemporaryDirectory(prefix='gta4l-ui-'+args.ui+'-',dir=base) as temporary:
    temporary=Path(temporary)
    archive=temporary/'rootfs.tar.gz'
    raw=temporary/'rootfs.tar'
    # Recovery creates the user's home from /etc/skel after extracting rootfs.
    excluded=['./home','./proc/*','./sys/*','./dev/*','./run/*','./tmp/*','./mnt/*','./var/cache/apk/*']
    command=['tar','--one-file-system','--numeric-owner','--sort=name','-C',str(root),'-cf',str(raw)]
    command+=['--exclude='+item for item in excluded]+['.']
    print('ARCHIVING_ROOTFS '+args.ui,flush=True)
    subprocess.run(command,check=True)
    # Host-native gzip avoids repeating ARM64 emulation for image compression.
    with archive.open('wb') as target:
        subprocess.run(['gzip','-1','-c',str(raw)],stdout=target,check=True)
    raw.unlink()
    print('VERIFYING_EMBEDDED_CONTENT '+args.ui,flush=True)
    found=set();found_modules=set();found_keys=set();embedded=None
    with tarfile.open(archive,'r:gz') as tar:
        for member in tar:
            name=member.name.removeprefix('./')
            assert name!='home' and not name.startswith('home/'),'Recovery must create a fresh home'
            module_name=name.removeprefix('usr/') if name.startswith('usr/lib/modules/') else name
            if member.isfile() and module_name in modules:
                assert hashlib.sha256(tar.extractfile(member).read()).hexdigest()==modules[module_name]
                found_modules.add(module_name)
            elif name=='boot/boot.img':assert tar.extractfile(member).read()==stable;found.add('boot')
            elif name in keys:
                assert member.isfile() and member.uid==0 and member.gid==0
                assert hashlib.sha256(tar.extractfile(member).read()).hexdigest()==keys[name]
                found_keys.add(name)
            elif name in ('lib/apk/db/installed','usr/lib/apk/db/installed'):
                embedded={}
                for section in tar.extractfile(member).read().decode().split('\n\n'):
                    item=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
                    if 'P' in item:embedded[item['P']]=item['V']
    assert found=={'boot'} and found_modules==set(modules)
    assert found_keys==set(keys),'Embedded package-update trust keys differ'
    assert embedded==records,'Embedded APK database differs from the verified rootfs'
    print('ASSEMBLING_ORANGEFOX_ZIP '+args.ui,flush=True)
    intermediate=temporary/'source.zip'
    with zipfile.ZipFile(template) as source,zipfile.ZipFile(intermediate,'w',allowZip64=True) as destination:
        for member in source.infolist():
            if member.filename=='rootfs.tar.gz':destination.write(archive,member.filename,compress_type=zipfile.ZIP_STORED)
            else:
                with source.open(member) as incoming,destination.open(member,'w',force_zip64=True) as outgoing:
                    while chunk:=incoming.read(1024*1024):outgoing.write(chunk)
    installer_report=artifacts/(args.ui+'-installer-verification.json')
    print('VERIFYING_INSTALLER_AND_CRC '+args.ui,flush=True)
    native_output=temporary/'candidate.zip'
    subprocess.run([sys.executable,str(workspace/'tools/package-recovery.py'),str(intermediate),str(native_output),
                    '--expected-boot',str(workspace/'artifacts/boot-current.img'),'--rootfs-report',str(args.root_report),
                    '--report',str(installer_report),'--package-revision','5'],check=True)
    print('COPYING_VERIFIED_INSTALLER '+args.ui,flush=True)
    partial=output.with_suffix('.zip.partial')
    shutil.copyfile(native_output,partial)
    assert partial.stat().st_size==native_output.stat().st_size
    partial.replace(output)
report={'ui':args.ui,'name':profiles[args.ui]['name'],'build_host':'WSL Ubuntu',
        'package':output.name,'bytes':output.stat().st_size,'sha256':None,
        'boot_sha256':boot_hash,'boot_bytes':len(stable),'kernel_release':9,'device_release':23,
        'embedded_modules_verified':37,'embedded_apk_database_verified':True,
        'packaging_schema':2,'apk_signing_keys_verified':keys,
        'selected_packages':{name:records[name] for name in expected},
        'ui_packages':{name:version for name,version in records.items() if name.startswith('postmarketos-ui-')},
        'session_type':profiles[args.ui]['session_type'],'display_manager':profiles[args.ui]['display_manager'],
        'desktop_packages':root_report['desktop_packages'],
        'session_descriptors':root_report['session_descriptors'],
        'ui_overlay_sha256':root_report.get('ui_overlay_sha256',{}),
        'audio_backend':'PulseAudio with the tested internal-card interrupt policy',
        'desktop_rendering':'software','formats_userdata':True,
        'rootfs_runtime_verified':False,'installer_flashing_verified':False,
        'preserves_partitions':['recovery','dtbo','super','modem','EFS','persist','bootloader'],
        'source_template_sha256':template_ready['sha256']}
with output.open('rb') as stream:report['sha256']=hashlib.file_digest(stream,'sha256').hexdigest()
(artifacts/(args.ui+'-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
print('LOCAL_UI_PACKAGE_VERIFIED '+args.ui+' bytes='+str(report['bytes']),flush=True)
