#!/usr/bin/env python3
"""Extract a locally signed ARM64 driver and prepare a one-boot test."""
from pathlib import Path
import base64
import hashlib
import struct
import tarfile

package = Path('artifacts/apks/xorg-modesetting-gta4l-21.1.25-r0.apk')
with tarfile.open(package, 'r:gz', ignore_zeros=True) as archive:
    selected = [m for m in archive if m.name.lstrip('./') == 'usr/lib/xorg/modules/drivers/modesetting_drv.so']
    assert len(selected) == 1 and selected[0].isfile()
    data = archive.extractfile(selected[0]).read()
assert data[:4] == b'\x7fELF' and struct.unpack_from('<H', data, 18)[0] == 183
Path('artifacts/modesetting_drv-gta4l.so').write_bytes(data)
digest = hashlib.sha256(data).hexdigest()
command = "stty -echo\nprintf '\\nGTA4L_MODESETTING_FIX_BEGIN\\n'\nbase64 -d > /tmp/modesetting_drv-gta4l.so <<'GTA4L_DRIVER_DATA'\n"
command += base64.encodebytes(data).decode('ascii') + 'GTA4L_DRIVER_DATA\n'
command += f"(set -eu\nprintf '%s\\n' '{digest}  /tmp/modesetting_drv-gta4l.so' | sha256sum -c -\n"
command += """chmod 755 /tmp/modesetting_drv-gta4l.so
rc-service lightdm stop
mount --bind /tmp/modesetting_drv-gta4l.so /usr/lib/xorg/modules/drivers/modesetting_drv.so
cat > /tmp/gta4l-modesetting.conf <<'GTA4L_CONFIG_END'
Section "Device"
    Identifier "SM-T505 framebuffer"
    Driver "modesetting"
    Option "kmsdev" "/dev/dri/card0"
    Option "AccelMethod" "none"
    Option "SWcursor" "true"
    Option "ShadowFB" "true"
    Option "PageFlip" "false"
EndSection
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
GTA4L_CONFIG_END
mount --bind /tmp/gta4l-modesetting.conf /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf
printf '<6>GTA4L_TEST: patched modesetting output property setter\\n' > /dev/kmsg
rc-service lightdm start
)
printf '\\nGTA4L_MODESETTING_FIX_END\\n'
stty echo
"""
Path('artifacts/live-upload-modesetting.sh').write_text(command, newline='\n')
print(f'Prepared {len(data)} ARM64 driver bytes; sha256={digest}')
