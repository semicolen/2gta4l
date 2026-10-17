#!/usr/bin/env python3
"""Combine the current local rootfs with the exact hardware-tested #9 boot."""
from pathlib import Path
import copy,hashlib,io,json,struct,subprocess,tarfile,tempfile,zipfile
workspace=Path(__file__).resolve().parents[1];base=Path('/home/ark/sm-t505-port')
artifacts=workspace/'artifacts';root=base/'work/chroot_rootfs_samsung-gta4l'
stable=(artifacts/'boot-bluetooth-fix.img').read_bytes()
stable_hash='4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663'
assert hashlib.sha256(stable).hexdigest()==stable_hash
assert stable[:8]==b'ANDROID!'
ks,_,rs=struct.unpack_from('<3I',stable,8);page=struct.unpack_from('<I',stable,36)[0]
assert page==4096 and struct.unpack_from('<I',stable,40)[0]==2
align=lambda n:(n+page-1)//page*page
ramdisk_offset=page+align(ks)
ramdisk=stable[ramdisk_offset:ramdisk_offset+rs]
dtb_offset=ramdisk_offset+align(rs);ds=struct.unpack_from('<I',stable,1648)[0]
assert stable[page:page+ks]==(root/'boot/vmlinuz').read_bytes()
assert stable[dtb_offset:dtb_offset+ds]==(root/'boot/dtbs/qcom/gta4l.dtb').read_bytes()
modules=json.loads((artifacts/'bluetooth-fix-verification.json').read_text())['modules_sha256']
for name,digest in modules.items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name
assert len(modules)==37
(artifacts/'boot-current.img').write_bytes(stable)
source=base/'work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gta4l.zip'
ready=json.loads((artifacts/'current-recovery-source-ready.json').read_text())
assert ready['source']==str(source) and ready['bytes']==source.stat().st_size
with source.open('rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==ready['sha256']
intermediate=base/'current-rootfs-tested-boot.zip'
output=artifacts/'postmarketOS-SM-T505-OrangeFox-bringup-r4.zip'
overrides={'boot/boot.img':stable,'boot/initramfs':ramdisk}
with tempfile.TemporaryDirectory(prefix='gta4l-current-installer-',dir=base) as directory:
    archive=Path(directory)/'rootfs.tar.gz';found=set();found_modules=set();installed=None
    audio_files={
        'usr/lib/udev/rules.d/90-gta4l-audio.rules':workspace/'port/alsa-ucm-gta4l/90-gta4l-audio.rules',
        'etc/pulse/default.pa.d/90-gta4l-audio.pa':workspace/'port/alsa-ucm-gta4l/90-gta4l-audio.pa'}
    found_audio=set()
    print('Embedding the exact tested boot and initramfs in the current rootfs',flush=True)
    with zipfile.ZipFile(source) as src:
        with src.open('rootfs.tar.gz') as stream,tarfile.open(fileobj=stream,mode='r|gz') as incoming,tarfile.open(archive,'w:gz',compresslevel=3) as outgoing:
            for member in incoming:
                name=member.name.removeprefix('./')
                if name in audio_files:
                    data=incoming.extractfile(member).read()
                    assert data==audio_files[name].read_bytes(),name
                    found_audio.add(name)
                    outgoing.addfile(member,io.BytesIO(data));continue
                module_name=name.removeprefix('usr/') if name.startswith('usr/lib/modules/') else name
                if member.isfile() and module_name in modules:
                    data=incoming.extractfile(member).read()
                    assert hashlib.sha256(data).hexdigest()==modules[module_name],module_name
                    found_modules.add(module_name)
                    outgoing.addfile(member,io.BytesIO(data));continue
                if name in ('lib/apk/db/installed','usr/lib/apk/db/installed'):
                    data=incoming.extractfile(member).read();installed={}
                    expected={'linux-samsung-gta4l':'4.19.300-r8','device-samsung-gta4l':'1-r22',
                              'camera-gta4l':'1.0-r2','gps-gta4l':'1.0-r3','modemmanager':'1.25.95_git20261005-r3',
                              'alsa-ucm-gta4l':'1.0-r3','alsa-ucm-gta4l-pulseaudio':'1.0-r3'}
                    for section in data.decode().split('\n\n'):
                        values=dict(line.split(':',1) for line in section.splitlines() if ':' in line)
                        if values.get('P') in expected:installed[values['P']]=values['V']
                    assert installed==expected,installed
                    outgoing.addfile(member,io.BytesIO(data));continue
                if name in overrides:
                    assert member.isfile(),name
                    payload=overrides[name];updated=copy.copy(member);updated.size=len(payload)
                    outgoing.addfile(updated,io.BytesIO(payload));found.add(name)
                else:
                    outgoing.addfile(member,incoming.extractfile(member) if member.isfile() else None)
        assert found==set(overrides),found
        assert found_modules==set(modules),found_modules
        assert found_audio==set(audio_files),found_audio
        assert installed is not None
        with zipfile.ZipFile(intermediate,'w',allowZip64=True) as dst:
            for member in src.infolist():
                if member.filename=='rootfs.tar.gz':
                    dst.write(archive,member.filename,compress_type=zipfile.ZIP_STORED)
                else:
                    with src.open(member) as incoming,dst.open(member,'w',force_zip64=True) as outgoing:
                        while chunk:=incoming.read(1024*1024):outgoing.write(chunk)
for name,payload in overrides.items():(root/name).write_bytes(payload)
for tool,args in [('verify-initramfs.py',['--report',str(artifacts/'initramfs-current-verification.json')]),
                  ('verify-boot.py',[str(artifacts/'boot-current.img'),str(artifacts/'boot-current-verification.json')]),
                  ('test-recovery-installer.py',[]),
                  ('package-recovery.py',[str(intermediate),str(output),
                    '--expected-boot',str(artifacts/'boot-current.img'),
                    '--rootfs-report',str(artifacts/'rootfs-current-verification.json'),
                    '--report',str(artifacts/'installer-current-verification.json'),
                    '--package-revision','4'])]:
    subprocess.run(['python3',str(workspace/'tools'/tool),*args],check=True)
report={'build_host':'WSL Ubuntu','package_revision':4,'device_release':22,
    'camera_release':2,'audio_release':3,'kernel_release':9,'boot_sha256':stable_hash,
    'boot_bytes':len(stable),'all_37_modules_match_tested_kernel':True,
    'embedded_rootfs_selected_packages':installed,
    'embedded_audio_startup_policy_verified':True,
    'boot_kernel_ramdisk_dtb_header_byte_identical_to_running_tablet':True,
    'rootfs_runtime_verified':False,'installer_flashing_verified':False,
    'package':output.name,'bytes':output.stat().st_size,
    'sha256':None}
with output.open('rb') as stream:report['sha256']=hashlib.file_digest(stream,'sha256').hexdigest()
(artifacts/'current-build-verification.json').write_text(json.dumps(report,indent=2)+'\n')
(artifacts/'SHA256SUMS-current').write_text(report['sha256']+'  '+output.name+'\n'+stable_hash+'  boot-current.img\n')
print('CURRENT_ORANGEFOX_R4_PACKAGE_BUILT_AND_VERIFIED: '+str(report['bytes'])+' bytes',flush=True)
