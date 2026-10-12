"""Verify GPS request-path packages and prepare a guarded incremental update."""
from pathlib import Path
import hashlib
import json
import tarfile

root=Path(__file__).resolve().parents[1]
names=[x+'-1.25.95_git20261005-r3.apk' for x in ['modemmanager','modemmanager-openrc','modemmanager-udev','libmm-glib']]
names+=['gps-gta4l-1.0-r3.apk']
names+=[x+'-1-r20.apk' for x in ['device-samsung-gta4l','device-samsung-gta4l-openrc','device-samsung-gta4l-nonfree-firmware']]
contents={}; hashes={}
for name in names:
    path=root/'artifacts/apks'/name
    hashes[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        contents[name]={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    expected=b'noarch' if ('-openrc-' in name or '-udev-' in name) else b'aarch64'
    assert b'arch = '+expected+b'\n' in contents[name]['.PKGINFO']
mm=contents[names[0]]['usr/sbin/ModemManager']
assert mm[:4]==b'\x7fELF' and int.from_bytes(mm[18:20],'little')==183
assert b'Preparing SM-T505 GPS engine through QMI LOC' in mm
assert b'/etc/ModemManager/gta4l-gps-unlock' in mm
assert b'/usr/bin/qmicli' not in mm
assert b'depend = modemmanager=1.25.95_git20261005-r3\n' in contents['gps-gta4l-1.0-r3.apk']['.PKGINFO']
assert 'etc/ModemManager/gta4l-gps-unlock' in contents['gps-gta4l-1.0-r3.apk']
checks='\n'.join(v+'  /tmp/gta4l-upload/'+n for n,v in hashes.items())
packages=' '.join('/tmp/gta4l-upload/'+n for n in names)
script=f'''#!/bin/sh
set -eu
boot_hash() {{ head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
apk --no-network --no-interactive --no-scripts add {packages}
rc-update -q del gta4l-gps-prepare default 2>/dev/null || true
if apk info -e gps-gta4l-openrc >/dev/null 2>&1; then
    rc-service gta4l-gps-prepare stop || true
    apk --no-network --no-interactive --no-scripts del gps-gta4l-openrc
fi
service=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
mkdir -p /var/log/gta4l/gps-private
chmod 700 /var/log/gta4l/gps-private
cp /etc/conf.d/modemmanager /var/log/gta4l/gps-private/modemmanager.confd.before-r20
printf '%s\\n' 'modemmanager_opts="--test-quick-suspend-resume --log-file=/var/log/gta4l/gps-private/modemmanager-direct.log"' > /etc/conf.d/modemmanager
override=/tmp/gta4l-mm-gps-activation.service
cat > "$override" <<'ACTIVATION'
[D-BUS Service]
Name=org.freedesktop.ModemManager1
Exec=/bin/false
User=root
ACTIVATION
restore_activation() {{
    umount "$service"
    dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
}}
mount --bind "$override" "$service"
trap restore_activation EXIT
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
rc-service modemmanager stop
rc-service modemmanager start
restore_activation
trap - EXIT
sleep 4
rc-service modemmanager status
mmcli -L
test -f /etc/ModemManager/gta4l-gps-unlock
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo GPS_REQUEST_PATH_R20_INSTALLED_BOOT_UNCHANGED
'''
(root/'tools/live-install-gps-r20.sh').write_text(script,newline='\n')
path=root/'artifacts/gps-verification.json'
v=json.loads(path.read_text()); v['packages']=hashes; v['device_release']=20
v['startup_after_reboot_verified']=False
v['request_path_unlock_verified']=False
path.write_text(json.dumps(v,indent=2)+'\n')
print('Verified GPS request quirk in ARM64 ModemManager and exact package dependencies')
