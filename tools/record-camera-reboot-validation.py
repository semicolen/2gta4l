"""Record the fresh desktop camera check after device-r21 reboot."""
from pathlib import Path
import hashlib, json, re

root = Path(__file__).resolve().parents[1]
evidence = root/'evidence/diagnostic-boot-20261009'
post = (evidence/'device-r21-camera-post-reboot-state.raw').read_text()
active = (evidence/'device-r21-camera-app-after-reboot-state.raw').read_text()
closed = (evidence/'device-r21-camera-app-after-reboot-closed.raw').read_text()
control = (evidence/'device-r21-camera-controller-after-reboot-check.raw').read_text()
assert 'CAMERA_CONTROLLER_STARTED_IDLE_AFTER_REBOOT' in post
assert '--preview-rear' in active
assert re.search(r'frame bytes=921615 uid=0 gid=27 mode=0o640 age_seconds=0\.', active)
assert 'CAMERA_SEQUENCE id=1 completed=51 preview=1 stop_requested=1' in closed
for stage in ('FLUSH', 'CLOSE'):
    assert f'CAMERA_{stage} id=1 result=0' in closed
assert 'CAMERA_BUFFER_RELEASE result=0' in closed and 'frame absent' in closed
assert '--preview-' not in closed
assert re.search(r'saved_photos=6\b', closed)
assert 'CAMERA_CONTROLLER_CHECK_PASSED' in control
boot = re.search(r'^([0-9a-f-]{36})$', post, re.M)[1]
path = root/'artifacts/camera-verification.json'
data = json.loads(path.read_text())
data.update(startup_after_reboot_verified=True,
    reboot_preview_and_photo_verified_by_user=True,
    post_reboot_boot_id=boot, saved_photo_count_at_validation=6)
# Older still-review output also included the shell source; match the actual
# UUID line instead of accidentally recording its Python print statement.
review = (evidence/'device-r20-camera-review-state.raw').read_text()
data['boot_id'] = re.search(r'^boot_id=([0-9a-f-]{36})$', review, re.M)[1]
data['reboot_evidence'] = {
    name: hashlib.sha256((evidence/name).read_bytes()).hexdigest()
    for name in ('device-r21-camera-post-reboot-state.raw',
                 'device-r21-camera-app-after-reboot-state.raw',
                 'device-r21-camera-app-after-reboot-closed.raw',
                 'device-r21-camera-controller-after-reboot-check.raw')}
path.write_text(json.dumps(data, indent=2)+'\n')
print('CAMERA_FRESH_REBOOT_PREVIEW_PHOTO_AND_CLEANUP_VALIDATION_PASSED')
