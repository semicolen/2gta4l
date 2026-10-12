"""Verify the local GPS packages and generate a boot-preserving update script."""
from pathlib import Path
import hashlib
import json
import tarfile

root=Path(__file__).resolve().parents[1]
names=['geoclue-2.8.2-r0.apk','gps-gta4l-1.0-r0.apk','gps-gta4l-openrc-1.0-r0.apk',
       'avahi-glib-0.9_rc5-r0.apk']
names += [x+'-1-r17.apk' for x in ['device-samsung-gta4l','device-samsung-gta4l-openrc','device-samsung-gta4l-nonfree-firmware']]
contents={}; hashes={}
for name in names:
    path=root/'artifacts/apks'/name
    hashes[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    with tarfile.open(path,'r:gz',ignore_zeros=True) as archive:
        contents[name]={m.name.removeprefix('./'):archive.extractfile(m).read() for m in archive if m.isfile()}
    expected=b'noarch' if '-openrc-' in name else b'aarch64'
    assert b'arch = '+expected+b'\n' in contents[name]['.PKGINFO']
for name in ['usr/libexec/geoclue','usr/libexec/geoclue-2.0/demos/agent','usr/libexec/geoclue-2.0/demos/where-am-i']:
    elf=contents[names[0]][name]
    assert elf[:4]==b'\x7fELF' and int.from_bytes(elf[18:20],'little')==183
assert b'depend = gps-gta4l\n' in contents['device-samsung-gta4l-1-r17.apk']['.PKGINFO']
assert b'depend = gps-gta4l-openrc\n' in contents['device-samsung-gta4l-openrc-1-r17.apk']['.PKGINFO']
assert contents[names[1]]['usr/libexec/gta4l-gps-prepare']==(root/'port/gps-gta4l/gta4l-gps-prepare.py').read_bytes()
checks='\n'.join(v+'  /tmp/gta4l-upload/'+n for n,v in hashes.items())
packages=' '.join('/tmp/gta4l-upload/'+n for n in names)
script=f'''#!/bin/sh
set -eu
boot_hash() {{ head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }}
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
{checks}
HASHES
getent group geoclue >/dev/null || addgroup -S geoclue
id geoclue >/dev/null 2>&1 || adduser -S -D -h /var/lib/geoclue -s /sbin/nologin -G geoclue geoclue
apk --no-network --no-interactive --no-scripts add {packages}
install -d -m 700 -o geoclue -g geoclue /var/lib/geoclue
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
rc-update -q add gta4l-gps-prepare default
rc-service gta4l-gps-prepare start
mmcli -m 0 --location-disable-gps-raw --location-disable-gps-nmea
mmcli -m 0 --location-status
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo GPS_INTEGRATION_INSTALLED_BOOT_UNCHANGED
'''
(root/'tools/live-install-gps.sh').write_text(script,newline='\n')
path=root/'artifacts/gps-verification.json'
v=json.loads(path.read_text()); v['packages']=hashes; v['device_release']=17
path.write_text(json.dumps(v,indent=2)+'\n')
print('Verified ARM64 location binaries, device dependencies and package hashes')
