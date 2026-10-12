#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib

data = Path('artifacts/apks/xorg-modesetting-gta4l-21.1.25-r0.apk').read_bytes()
digest = hashlib.sha256(data).hexdigest()
command = "stty -echo\nprintf '\\nGTA4L_MODESETTING_INSTALL_BEGIN\\n'\nbase64 -d > /tmp/xorg-modesetting-gta4l.apk <<'GTA4L_APK_END'\n"
command += base64.encodebytes(data).decode('ascii') + 'GTA4L_APK_END\n'
command += f"(set -eu\nprintf '%s\\n' '{digest}  /tmp/xorg-modesetting-gta4l.apk' | sha256sum -c -\n"
command += """rc-service lightdm stop
if grep -q ' /usr/lib/xorg/modules/drivers/modesetting_drv.so ' /proc/mounts; then
    umount /usr/lib/xorg/modules/drivers/modesetting_drv.so
fi
mkdir -p /var/log/gta4l/compat-backups
if [ ! -f /var/log/gta4l/compat-backups/modesetting_drv.so.original ]; then
    cp -p /usr/lib/xorg/modules/drivers/modesetting_drv.so /var/log/gta4l/compat-backups/modesetting_drv.so.original
fi
apk --no-network --no-interactive add /tmp/xorg-modesetting-gta4l.apk
sha256sum /usr/lib/xorg/modules/drivers/modesetting_drv.so
apk --no-network info -W /usr/lib/xorg/modules/drivers/modesetting_drv.so
rc-service lightdm start
sync
echo 'Installed verified vendor DRM property compatibility driver'
)
printf '\\nGTA4L_MODESETTING_INSTALL_END\\n'
stty echo
"""
Path('artifacts/live-install-modesetting.sh').write_text(command, newline='\n')
print(f'Prepared signed {len(data)} byte modesetting package; sha256={digest}')
