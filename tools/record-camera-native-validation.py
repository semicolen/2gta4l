"""Record user-confirmed native preview and controller cleanup checks."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
base=root/'evidence/diagnostic-boot-20261009'
closed=(base/'device-r20-camera-app-r0-closed.raw').read_text()
assert re.search(r'saved_photos=([1-9]\d*)',closed)
assert 'CAMERA_SEQUENCE id=0 completed=84 preview=1 stop_requested=1' in closed
assert 'CAMERA_CLOSE id=0 result=0' in closed and 'CAMERA_BUFFER_RELEASE result=0' in closed
assert 'frame absent' in closed
assert '/system/bin/camera-hal-enumerate --preview-' not in closed
assert 'python3 /usr/bin/gta4l-camera\n' not in closed
control=(base/'device-r20-camera-controller-r0-check.raw').read_text()
assert 'CAMERA_CONTROLLER_CHECK_PASSED' in control
assert 'CAMERA_CONTROLLER_UNPRIVILEGED_ACCESS_DENIED' in control
post=(base/'device-r21-camera-post-reboot-state.raw').read_text()
assert 'CAMERA_CONTROLLER_STARTED_IDLE_AFTER_REBOOT' in post
path=root/'artifacts/camera-verification.json'
data=json.loads(path.read_text())
data.update(live_preview_verified=True,desktop_photo_saving_verified=True,
    preview_rotation_all_four_verified_by_user=True,controller_cleanup_verified=True,
    controller_access_and_command_checks_verified=True,controller_startup_after_reboot_verified=True,
    saved_photo_count_at_validation=int(re.search(r'saved_photos=(\d+)',closed)[1]),
    post_reboot_boot_id=re.search(r'^([0-9a-f-]{36})$',post,re.M)[1])
streams=(base/'device-r20-camera-supported-streams.raw').read_text()
for name,id in [('rear',0),('front',1)]:
    sizes=[(int(w),int(h)) for w,h in re.findall(rf'CAMERA_SUPPORTED_STREAM id={id} format=0x23 width=(\d+) height=(\d+) direction=0',streams)]
    data['cameras'][name]['advertised_maximum_yuv_size']=list(max(sizes,key=lambda s:s[0]*s[1]))
path.write_text(json.dumps(data,indent=2)+'\n')
print('CAMERA_NATIVE_PREVIEW_PHOTO_ROTATION_AND_CLEANUP_VALIDATION_PASSED')
