"""Record GPS evidence without publishing the device's coordinates."""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[1]
evidence=root/'evidence/diagnostic-boot-20261009'
window=(evidence/'device-r16-gps-window-1.raw').read_text()
assert 'raw_coordinates_present=True' in window
assert '$GPRMC status=A' in window
assert '$GPGGA quality=1 satellites=09 hdop=0.6' in window
failure=(evidence/'device-r16-gps-start-trace.raw').read_text()
success=(evidence/'device-r16-gps-unlock-test.raw').read_text()
assert "GeneralError" in failure and 'successfully setup location gathering' in success
path=root/'artifacts/gps-verification.json'
v=json.loads(path.read_text()) if path.exists() else {}
v.update(
    gps_engine_start_verified=True,
    hardware_gps_fix_verified=True,
    valid_nmea_rmc=True,
    gga_fix_quality=1,
    satellites_used=9,
    hdop=0.6,
    test_position='open window; coordinates kept private',
    desktop_geoclue_verified=v.get('desktop_geoclue_verified',False),
    startup_after_reboot_verified=v.get('startup_after_reboot_verified',False),
    kernel='#9-postmarketOS unchanged',
    evidence=['device-r16-gps-start-trace.raw','device-r16-gps-unlock-test.raw','device-r16-gps-window-1.raw'])
path.write_text(json.dumps(v,indent=2)+'\n')
print('Recorded valid hardware GPS fix; desktop integration and reboot checks pending')
