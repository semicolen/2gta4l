"""Record fresh r2 reboot tests of the installed GTK preview/shutter/save path."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1];evidence=root/'evidence/diagnostic-boot-20261009'
post=evidence/'device-r21-camera-r2-post-reboot-state.raw'
assert 'CAMERA_CONTROLLER_STARTED_IDLE_AFTER_REBOOT' in post.read_text()
boot=re.search(r'^([0-9a-f-]{36})$',post.read_text(),re.M)[1]
names=[post.name]
for camera,size in [('rear',(3264,2448)),('front',(2592,1944))]:
    name=f'device-r21-camera-r2-native-{camera}-after-reboot.raw'
    text=(evidence/name).read_text()
    assert f'CAMERA_NATIVE_PREVIEW_READY camera={camera}' in text
    result=re.search(rf'CAMERA_NATIVE_PHOTO_SAVED camera={camera} width=(\d+) height=(\d+) bytes=(\d+)',text)
    assert result and sorted((int(result[1]),int(result[2])))==sorted(size)
    assert int(result[3])>24
    assert f'CAMERA_NATIVE_PREVIEW_RESTARTED camera={camera}' in text
    assert 'CAMERA_NATIVE_PHOTO_REGRESSION_EXIT=0' in text
    names.append(name)
name='device-r21-camera-r2-final-state.raw';final=(evidence/name).read_text()
assert f'boot_id={boot}' in final
assert 'CAMERA_R2_POST_REBOOT_IDLE_AND_CLEANUP_VERIFIED' in final
assert '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' in final
names.append(name)
path=root/'artifacts/camera-verification.json';data=json.loads(path.read_text())
assert data['native_app_release']==2
data.update(startup_after_reboot_verified=True,controller_startup_after_reboot_verified=True,
    native_both_cameras_full_photo_after_reboot_verified=True,
    post_reboot_boot_id=boot,saved_photo_count_at_validation=int(re.search(r'saved_photos=(\d+)',final)[1]))
if 'previous_reboot_evidence_r1' not in data:
    data['previous_reboot_evidence_r1']=data.pop('reboot_evidence',{})
    data['previous_reboot_preview_and_photo_verified_by_user']=data.pop('reboot_preview_and_photo_verified_by_user',False)
data['reboot_verification_method']='Automated native GTK shutter/save/restart tests for both cameras; user confirms desktop login'
data['reboot_evidence']={name:hashlib.sha256((evidence/name).read_bytes()).hexdigest() for name in names}
path.write_text(json.dumps(data,indent=2)+'\n')
print('CAMERA_R2_BOTH_NATIVE_FULL_PHOTOS_AFTER_REBOOT_VALIDATION_PASSED')
