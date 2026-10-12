"""Record bounded hardware capture results without copying private images."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
evidence=root/'evidence/diagnostic-boot-20261009'
result={'stock_version':'T505XXS8CXG1','device_release':20,'kernel_release':9,
    'stock_hal_sha256':'3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8',
    'local_build_environment':'WSL Ubuntu','camera_count':2,
    'visual_still_images_verified_by_user':True,'live_preview_verified':False,
    'desktop_photo_saving_verified':False,'startup_after_reboot_verified':False,
    'resolution_verified':[640,480],'cameras':{}}
state=(evidence/'device-r20-camera-review-state.raw').read_text()
for name,id,sensor,profile,orientation in [('rear',0,'HI846','n19_hi846_back_txd',90),
                                          ('front',1,'GC5035','n19_gc5035_front_qunhui',270)]:
    path=evidence/f'device-r20-camera-{name}-sequence.raw'
    text=path.read_text()
    for stage in ('OPEN','INITIALIZE','CONFIGURE','FLUSH','CLOSE'):
        assert re.search(rf'CAMERA_{stage} id={id} result=0\b',text),stage
    frames=re.findall(rf'CAMERA_CAPTURE id={id} frame=(\d+) result=0 buffer_returned=1',text)
    assert frames==[str(i) for i in range(1,31)]
    assert 'CAMERA_BUFFER_RELEASE result=0' in text
    assert 'CAMERA_HAL_ISOLATED_TEST_END' in text and 'SIGSEGV' not in text
    image=re.search(r'CAMERA_IMAGE_SAVED success=1 luma_min=(\d+) luma_max=(\d+) luma_mean=(\d+)',text)
    assert image and int(image[2])-int(image[1])>100
    file=re.search(rf'{name} bytes=(\d+) sha256=([0-9a-f]{{64}})',state)
    assert file and int(file[1])==921615
    result['cameras'][name]={'camera_id':id,'sensor':sensor,'stock_profile':profile,
        'sensor_orientation':orientation,'successful_frames':30,
        'luma_min':int(image[1]),'luma_max':int(image[2]),'luma_mean':int(image[3]),
        'image_bytes':int(file[1]),'image_sha256':file[2],
        'evidence':path.name,'evidence_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
result['boot_id']=re.search(r'boot_id=([^\s]+)',state)[1]
(root/'artifacts/camera-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('CAMERA_STILL_CAPTURE_VALIDATION_PASSED: 30 frames each, clean close, user confirmed both images')
