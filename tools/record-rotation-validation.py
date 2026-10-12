"""Record bounded rotation results and their actual device evidence."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
report_path = root/'artifacts/rotation-verification.json'
report = json.loads(report_path.read_text())
report.update(runtime_rotation_verified=True, startup_after_reboot_verified=True,
              lockscreen_resize_verified=True, lockscreen_unlock_user_confirmed=True,
              rotation_lock_control_verified=True,
              reboot_boot_id='89306779-6e9f-4d87-bbf3-f3ad5902614a',
              scope='Xfce desktop rotation and aligned touch; initial login remains portrait',
              kernel_unchanged='#9-postmarketOS')
report['evidence'] = [
    'device-r15-rotation-upright-corrected.raw',
    'device-r15-start-rotation.raw',
    'device-r16-sensors-after-reboot.raw',
    'device-r16-sensor-coldboot.raw',
    'device-r16-rotation-lock-control.raw']
report_path.write_text(json.dumps(report, indent=2)+'\n')
print('Recorded rotation, touch, lock-screen and one normal reboot validation')
