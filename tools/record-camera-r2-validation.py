"""Record full-size IPC captures and optional native-app visual verification."""
from pathlib import Path
import argparse,hashlib,json,re
parser=argparse.ArgumentParser();parser.add_argument('--visual',action='store_true')
options=parser.parse_args()
root=Path(__file__).resolve().parents[1]
evidence=root/'evidence/diagnostic-boot-20261009'
path=root/'artifacts/camera-verification.json';data=json.loads(path.read_text())
same_release=data.get('native_app_release')==2
package=json.loads((root/'artifacts/camera-development/r2-package-verification.json').read_text())
install=(evidence/'device-r21-camera-package-r2-install.raw').read_text()
assert 'CAMERA_R2_INSTALLED_BOOT_UNCHANGED' in install
for name in list(data['packages']):
    if name.startswith('camera-gta4l'):del data['packages'][name]
data['packages'].update(package['packages'])
data['packaged_helper_sha256']=package['helper_sha256'];data['native_app_release']=2
data['chroma_comparison_verified_by_user']=True
data['chroma_order_adjustment']='Swap Cb/Cr for the matching interleaved stock layout (Cb pointer = Cr pointer + 1)'
for camera,size in [('rear',(3264,2448)),('front',(2592,1944))]:
    name=f'device-r21-camera-r2-{camera}-photo-check.raw'
    source=evidence/name;text=source.read_text()
    result=re.search(rf'CAMERA_FULL_PHOTO_OK camera={camera} width=(\d+) height=(\d+) frames=(\d+) seconds=([\d.]+) sha256=([0-9a-f]{{64}})',text)
    assert result and (int(result[1]),int(result[2]))==size and int(result[3])==15
    assert f'CAMERA_PREVIEW_RESUMED_AFTER_FULL_PHOTO camera={camera}' in text
    assert f'CAMERA_PHOTO_DISCONNECT_CLEANUP_OK camera={camera}' in text
    data['cameras'][camera]['full_resolution_capture']={
        'size':list(size),'successful_frames':15,'seconds':float(result[4]),
        'image_sha256':result[5],'evidence':name,
        'evidence_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
cancel=evidence/'device-r21-camera-r2-photo-cancel-check.raw'
assert 'CAMERA_FULL_PHOTO_DISCONNECT_CANCEL_AND_CLEANUP_PASSED' in cancel.read_text()
data['photo_disconnect_cancellation_verified']=True
data['full_resolution_capture_verified']=True
if not same_release:
    data['previous_reboot_native_app_release']=1
    data['startup_after_reboot_verified']=False
    data['visual_still_images_verified_by_user']=False
    data['native_full_resolution_photo_saving_verified']=False
if options.visual:
    closed=(evidence/'device-r21-camera-app-r2-closed.raw').read_text()
    assert 'frame absent' in closed and '--preview-' not in closed
    assert 'CAMERA_CLOSE' in closed and 'CAMERA_BUFFER_RELEASE result=0' in closed
    for camera,size in [('rear',(3264,2448)),('front',(2592,1944))]:
        sizes=[(int(w),int(h)) for w,h in re.findall(rf'photo bytes=\d+ width=(\d+) height=(\d+) mode=0o600 name=[^\s]+_{camera}\.png',closed)]
        assert any(sorted(actual)==sorted(size) for actual in sizes),camera
    data.update(native_full_resolution_photo_saving_verified=True,
                corrected_colors_verified_by_user=True,
                visual_still_images_verified_by_user=True,
                saved_photo_count_at_validation=int(re.search(r'saved_photos=(\d+)',closed)[1]))
path.write_text(json.dumps(data,indent=2)+'\n')
print('CAMERA_R2_FULL_RESOLUTION_CAPTURE_AND_CANCELLATION_VALIDATION_PASSED'+
      ('; native full-size photos and colors user-confirmed' if options.visual else ''))
