#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib

source = Path('artifacts/apks/bubblewrap-gta4l-0.13.0-r0.apk')
data = source.read_bytes()
digest = hashlib.sha256(data).hexdigest()
command = """stty -echo
printf '\\nGTA4L_BWRAP_INSTALL_BEGIN\\n'
base64 -d > /tmp/bubblewrap-gta4l.apk <<'GTA4L_APK_END'
""" + base64.encodebytes(data).decode('ascii') + """GTA4L_APK_END
(set -eu
""" + f"printf '%s\\n' '{digest}  /tmp/bubblewrap-gta4l.apk' | sha256sum -c -\n" + """rc-service lightdm stop
mkdir -p /var/log/gta4l/compat-backups
if [ ! -f /var/log/gta4l/compat-backups/bwrap.original ]; then
    umount /usr/bin/bwrap
    cp -p /usr/bin/bwrap /var/log/gta4l/compat-backups/bwrap.original
    sha256sum /var/log/gta4l/compat-backups/bwrap.original
fi
apk --no-network --no-interactive add /tmp/bubblewrap-gta4l.apk
/usr/bin/bwrap --version
sha256sum /usr/bin/bwrap
rc-service lightdm start
sync
echo 'Installed locally built Linux 4.19 compatible Bubblewrap'
)
printf '\\nGTA4L_BWRAP_INSTALL_END\\n'
stty echo
"""
Path('artifacts/live-install-bwrap.sh').write_text(command, encoding='ascii', newline='\n')
print(f'Prepared {len(data)} package bytes; sha256={digest}')
