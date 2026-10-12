from pathlib import Path
import argparse
import base64
import hashlib

parser = argparse.ArgumentParser()
parser.add_argument('release', type=int)
args = parser.parse_args()
files = sorted(Path('artifacts/apks').glob(f'device-samsung-gta4l*-r{args.release}.apk'))
assert len(files) == 3
command = "stty -echo\nprintf '\\nGTA4L_DEVICE_INSTALL_BEGIN\\n'\nmkdir -p /tmp/gta4l-device-update\n"
checksums = []
for file in files:
    data = file.read_bytes()
    target = '/tmp/gta4l-device-update/' + file.name
    command += f"base64 -d > {target} <<'GTA4L_APK_END'\n" + base64.encodebytes(data).decode('ascii') + 'GTA4L_APK_END\n'
    checksums.append(hashlib.sha256(data).hexdigest() + '  ' + target)
command += "(set -eu\nsha256sum -c - <<'GTA4L_SHA_END'\n" + '\n'.join(checksums) + '\nGTA4L_SHA_END\n'
command += """apk --no-network --no-interactive --no-scripts add /tmp/gta4l-device-update/*.apk
cat /etc/udev/rules.d/98-touchscreen-cal.rules
udevadm control --reload-rules
sync
echo 'Installed device update without regenerating boot'
)
printf '\\nGTA4L_DEVICE_INSTALL_END\\n'
stty echo
"""
Path('artifacts/live-install-device.sh').write_text(command, newline='\n')
print(f'Prepared device release {args.release}, {len(files)} verified packages')
