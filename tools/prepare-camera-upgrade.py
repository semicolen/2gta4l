"""Validate the local r2 APKs and prepare the incremental camera-only update."""
from pathlib import Path
import hashlib,json,tarfile
root=Path(__file__).resolve().parents[1]
names=['camera-gta4l-1.0-r2.apk','camera-gta4l-openrc-1.0-r2.apk']
hashes={};contents={}
for name in names:
    path=root/'artifacts/apks'/name
    hashes[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    with tarfile.open(path,ignore_zeros=True) as archive:
        contents[name]={m.name.removeprefix('./'):archive.extractfile(m).read()
                        for m in archive if m.isfile()}
camera=contents[names[0]]
helper=camera['usr/lib/gta4l-camera/runtime/system/bin/camera-hal-enumerate']
assert helper[:4]==b'\x7fELF' and int.from_bytes(helper[18:20],'little')==183
assert b'--photo-rear' in helper and b'--photo-front' in helper
assert hashlib.sha256(camera['usr/lib/gta4l-camera/runtime/vendor/lib64/hw/camera.qcom.so']).hexdigest()=='3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8'
assert b"self.commands.put('photo')" in camera['usr/bin/gta4l-camera']
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
rc-service gta4l-camera start
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
printf 'CAMERA_R2_INSTALLED_BOOT_UNCHANGED\\n'
'''
(root/'tools/live-install-camera-package-r2.sh').write_text(script,newline='\n')
path=root/'artifacts/camera-development/r2-package-verification.json'
path.write_text(json.dumps(dict(packages=hashes,helper_sha256=hashlib.sha256(helper).hexdigest(),
    full_resolution_ui=True,build_environment='WSL Ubuntu'),indent=2)+'\n')
print('CAMERA_R2_APK_VALIDATION_PASSED')
