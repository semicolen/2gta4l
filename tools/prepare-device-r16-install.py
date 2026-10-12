"""Check device/locker ARM64 APKs and prepare the remaining rotation upgrade."""
from pathlib import Path
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[1]
names = [f'{name}-1-r16.apk' for name in
         ['device-samsung-gta4l','device-samsung-gta4l-openrc','device-samsung-gta4l-nonfree-firmware']]
names += ['xfce4-screensaver-4.20.2-r1.apk']
contents = {}
hashes = {}
for name in names:
    path = root/'artifacts/apks'/name
    hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    with tarfile.open(path, 'r:gz', ignore_zeros=True) as archive:
        contents[name] = {m.name.removeprefix('./'): archive.extractfile(m).read()
                          for m in archive if m.isfile()}
assert b'depend = rotation-gta4l\n' in contents[names[0]]['.PKGINFO']
assert b'depend = xfce4-screensaver=4.20.2-r1\n' in contents[names[0]]['.PKGINFO']
assert b'depend = sensors-gta4l-openrc\n' in contents[names[1]]['.PKGINFO']
for name in ['usr/bin/xfce4-screensaver','usr/libexec/xfce4-screensaver-dialog']:
    elf = contents[names[-1]][name]
    assert elf[:4] == b'\x7fELF' and int.from_bytes(elf[18:20], 'little') == 183
checks = '\n'.join(value+'  /tmp/gta4l-upload/'+name for name,value in hashes.items())
packages = ' '.join('/tmp/gta4l-upload/'+name for name in names)
script = f'''#!/bin/sh
set -eu
boot_hash() {{ head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
apk --no-network --no-interactive --no-scripts add {packages}
if [ -f /etc/udev/rules.d/81-gta4l-sensors.rules.apk-new ]; then
    cp /etc/udev/rules.d/81-gta4l-sensors.rules /var/lib/gta4l-sensors/81-gta4l-sensors.before-packaging.rules
    mv /etc/udev/rules.d/81-gta4l-sensors.rules.apk-new /etc/udev/rules.d/81-gta4l-sensors.rules
fi
rc-update -q add gta4l-sensors default
rc-update -q add iio-sensor-proxy default
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo DEVICE_R16_LOCKSCREEN_FIX_INSTALLED_BOOT_UNCHANGED
'''
(root/'tools/live-install-device-r16.sh').write_text(script, newline='\n')
report_path = root/'artifacts/rotation-verification.json'
report = json.loads(report_path.read_text())
report['packages'].update(hashes)
report['device_release'] = 16
report['touch_four_orientations_user_confirmed'] = True
report['lockscreen_resize_verified'] = False
report_path.write_text(json.dumps(report, indent=2)+'\n')
print('Verified device dependencies and ARM64 locker binaries')
