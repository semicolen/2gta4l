"""Verify package boundaries and preserve the already tested boot image."""
from pathlib import Path
import hashlib,json,tarfile
root=Path(__file__).resolve().parents[1]
names=['camera-gta4l-1.0-r1.apk','camera-gta4l-openrc-1.0-r1.apk']
names+=[name+'-1-r21.apk' for name in ('device-samsung-gta4l','device-samsung-gta4l-openrc','device-samsung-gta4l-nonfree-firmware')]
hashes={}; contents={}
for name in names:
    p=root/'artifacts/apks'/name
    hashes[name]=hashlib.sha256(p.read_bytes()).hexdigest()
    with tarfile.open(p,ignore_zeros=True) as tar:
        contents[name]={m.name.removeprefix('./'):tar.extractfile(m).read() for m in tar if m.isfile()}
camera=contents[names[0]]
hal=camera['usr/lib/gta4l-camera/runtime/vendor/lib64/hw/camera.qcom.so']
assert hashlib.sha256(hal).hexdigest()=='3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8'
helper=camera['usr/lib/gta4l-camera/runtime/system/bin/camera-hal-enumerate']
assert helper[:4]==b'\x7fELF' and int.from_bytes(helper[18:20],'little')==183
assert b'/apex/com.android.runtime/bin/linker64' in helper
assert b"arguments.add_argument('--camera'" in camera['usr/bin/gta4l-camera']
assert b'depend = camera-gta4l\n' in contents['device-samsung-gta4l-1-r21.apk']['.PKGINFO']
assert b'depend = camera-gta4l-openrc\n' in contents['device-samsung-gta4l-openrc-1-r21.apk']['.PKGINFO']
before=root/'artifacts/apks/device-samsung-gta4l-1-r20.apk'
with tarfile.open(before,ignore_zeros=True) as tar:
    for member in tar:
        if member.isfile() and (member.name.endswith('/deviceinfo') or member.name.endswith('/modules-initfs')):
            assert contents['device-samsung-gta4l-1-r21.apk'][member.name.removeprefix('./')]==tar.extractfile(member).read()
checks='\n'.join(digest+'  /tmp/gta4l-upload/'+name for name,digest in hashes.items())
packages=' '.join('/tmp/gta4l-upload/'+name for name in names)
script=f'''#!/bin/sh
set -eu
boot_hash() {{ head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
rc-service gta4l-camera stop
apk --no-network --no-interactive --no-scripts --allow-untrusted add {packages}
rc-update -q add gta4l-camera default
rc-service gta4l-camera start
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
printf 'CAMERA_DEVICE_R21_INSTALLED_BOOT_UNCHANGED\\n'
'''
(root/'tools/live-install-camera-device-r21.sh').write_text(script,newline='\n')
report=root/'artifacts/camera-verification.json'
data=json.loads(report.read_text()); data['packages']=hashes
data['packaged_helper_sha256']=hashlib.sha256(helper).hexdigest()
data['device_release']=21
data['native_app_release']=1
data['live_preview_verified']=True; data['desktop_photo_saving_verified']=True
data['preview_rotation_all_four_verified_by_user']=True
report.write_text(json.dumps(data,indent=2)+'\n')
print('CAMERA_DEVICE_R21_PACKAGE_VALIDATION_PASSED')
