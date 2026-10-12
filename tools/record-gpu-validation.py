#!/usr/bin/env python3
from pathlib import Path
import argparse
import hashlib
import json

parser = argparse.ArgumentParser()
parser.add_argument('--cube-visible', action='store_true', help='Record the user-confirmed kernel #8 cube')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence/diagnostic-boot-20261009'
user = (evidence / 'kgsl-gpu-compute-user-ion.raw').read_bytes()
admin = (evidence / 'kgsl-gpu-compute-root.raw').read_bytes()
cube = (evidence / 'kgsl-vkcube-x11-copy.raw').read_bytes()
summary = (evidence / 'kgsl-vulkan-summary-user.raw').read_bytes()
for test in [user, admin]:
    assert b'PASS: Adreno GPU computed and returned all 4096 results' in test
    assert b'Turnip Adreno (TM) 610' in test
assert b'X11 copy cube exit: 0' in cube and b'Selected GPU 0: Turnip Adreno (TM) 610' in cube
assert b'apiVersion         = 1.0.354' in summary
if args.cube_visible:
    visible = (evidence / 'kernel8-vkcube-visible-start.raw').read_bytes()
    assert b'Selected GPU 0: Turnip Adreno (TM) 610' in visible
    for name in ['root', 'user']:
        assert b'PASS: Adreno GPU computed and returned all 4096 results' in (evidence / f'kernel8-gpu-compute-{name}.raw').read_bytes()
packages = ['mesa-vulkan-kgsl-gta4l-26.2.4-r0.apk', 'vulkan-tools-gta4l-1.4.360-r0.apk']
report = {
    'build_host': 'WSL Ubuntu',
    'driver': 'Mesa 26.2.4 Turnip KGSL',
    'hardware': 'Adreno 610',
    'physical_device_vulkan_api': '1.0.354',
    'root_compute_readback_verified': True,
    'normal_user_compute_readback_verified': True,
    'compute_values_verified': 4096,
    'graphics_test': 'vkcube --wsi xlib --c 300 with MESA_VK_WSI_DEBUG=sw',
    'graphics_test_exit_status': 0,
    'presentation': 'CPU copy of hardware-rendered frames to X11',
    'physical_cube_visibility_verified': args.cube_visible,
    'desktop_opengl_accelerated': False,
    'vulkan_conformance_verified': False,
    'package_sha256': {name: hashlib.sha256((root / 'artifacts/apks' / name).read_bytes()).hexdigest()
                       for name in packages},
    'evidence': ['kgsl-gpu-compute-root.raw', 'kgsl-gpu-compute-user-ion.raw',
                 'kgsl-vkcube-x11-copy.raw', 'kgsl-vulkan-summary-user.raw'],
}
if args.cube_visible:
    report['physical_visibility_kernel'] = '#8-postmarketOS'
    report['evidence'] += ['kernel8-vkcube-visible-start.raw', 'kernel8-vkcube-visible-result.raw',
                           'kernel8-gpu-compute-root.raw', 'kernel8-gpu-compute-user.raw']
(root / 'artifacts/gpu-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('Recorded bounded GPU computation and X11 graphics verification')
