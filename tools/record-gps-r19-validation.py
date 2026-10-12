"""Record hardware request and reboot evidence without copying coordinates."""
from pathlib import Path
import hashlib
import json
import re

root=Path(__file__).resolve().parents[1]
folder=root/'evidence/diagnostic-boot-20261009'
names=[
    'device-r19-gps-install.raw',
    'device-r19-gps-regression-locked.raw',
    'device-r19-gps-running.raw',
    'device-r19-gps-window.raw',
    'device-r19-geoclue-result.raw',
    'device-r19-gps-client-stop.raw',
    'device-r19-gps-after-reboot.raw',
    'device-r19-gps-reboot-running.raw',
    'device-r19-gps-reboot-window.raw',
    'device-r19-geoclue-reboot-result.raw',
    'device-r19-gps-reboot-client-stop.raw',
]
e={name:(folder/name).read_text() for name in names}
def enabled_sources(text):
    match=re.search(r'\|\s*enabled:(.*?)\|\s*signals:',text,re.S)
    return match[1] if match else ''
assert 'GPS_REQUEST_PATH_R19_INSTALLED_BOOT_UNCHANGED' in e[names[0]]
assert 'GPS_REQUEST_REGRESSION_READY' in e[names[1]]
assert 'Successfully set engine lock' in e[names[1]]
assert re.search(r'value\s*= 03:00:00:00:00:00:00:00',e[names[1]])
for name in (names[2],names[7]):
    enabled=enabled_sources(e[name])
    assert 'gps-nmea' in enabled
    assert re.search(r'type\s*= 0x12\s*\n.*length\s*= 8\s*\n.*value\s*= 00:00:00:00:00:00:00:00',e[name])
fixes=[]
for name in (names[3],names[8]):
    text=e[name]
    assert 'nmea_coordinates_present=True' in text
    assert re.search(r'\$..RMC status=A',text)
    m=re.search(r'\$..GGA quality=([1-9]) satellites=(\d+) hdop=([0-9.]+)',text)
    assert m
    fixes.append(dict(gga_fix_quality=int(m[1]),satellites_used=int(m[2]),hdop=float(m[3])))
for name in (names[4],names[9]):
    assert 'where-am-i.log latitude_present=True' in e[name]
    assert 'where-am-i.log longitude_present=True' in e[name]
for name in (names[5],names[10]):
    assert 'GPS_CLIENT_STOPPED' in e[name]
    assert 'gps-' not in enabled_sources(e[name])
assert 'GPS_AFTER_REBOOT_END' in e[names[6]]
boot_id=re.search(r'\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b',e[names[6]])[0]
previous=(folder/'device-r17-gps-after-reboot.raw').read_text()
previous_id=re.search(r'\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b',previous)[0]
assert boot_id != previous_id
tests=(root/'logs/modemmanager-gps-tests.log').read_text()
assert re.search(r'Ok:\s+38',tests) and re.search(r'Fail:\s+0',tests)
path=root/'artifacts/gps-verification.json'
v=json.loads(path.read_text())
v.update(device_release=19,request_path_unlock_verified=True,
    desktop_geoclue_verified=True,startup_after_reboot_verified=True,
    location_client_shutdown_verified=True,
    boot_id=boot_id,
    hardware_request_fix=fixes[0],hardware_reboot_fix=fixes[1],
    modemmanager_unit_tests=dict(passed=38,failed=0),
    evidence=sorted(set(v.get('evidence',[])+names)))
v['packages']={name:hashlib.sha256((root/'artifacts/apks'/name).read_bytes()).hexdigest()
    for name in v['packages']}
path.write_text(json.dumps(v,indent=2)+'\n')
print('Recorded GPS request, satellite fix, desktop API, reboot and client shutdown checks')
