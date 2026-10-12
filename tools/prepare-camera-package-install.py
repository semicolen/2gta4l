"""Generate the checked incremental install and native desktop app launch."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
names=('camera-gta4l','camera-gta4l-openrc')
command='#!/bin/sh\nset -eu\n'
for name in names:
    file=name+'-1.0-r0.apk'
    digest=hashlib.sha256((root/'artifacts/apks'/file).read_bytes()).hexdigest()
    command+=f"printf '%s\\n' '{digest}  /tmp/gta4l-upload/{file}' | sha256sum -c -\n"
command+='''apk add --allow-untrusted /tmp/gta4l-upload/camera-gta4l-1.0-r0.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r0.apk
printf '%s\\n' '3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8  /usr/lib/gta4l-camera/runtime/vendor/lib64/hw/camera.qcom.so' | sha256sum -c -
rc-service gta4l-camera start
rc-update add gta4l-camera default
printf 'CAMERA_PACKAGE_R0_INSTALLED\\n'
'''
(root/'tools/live-install-camera-package-r0.sh').write_text(command,newline='\n')
print('Prepared verified incremental camera APK install')
