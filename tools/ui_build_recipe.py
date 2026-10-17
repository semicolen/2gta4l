"""Version and fingerprint the locally assembled UI installers."""
from pathlib import Path
import hashlib
import json

PACKAGE_REVISION = 14
PACKAGING_SCHEMA = 3


def tested_kernel(workspace: Path):
    """Require the checked #11 candidate while keeping #9 and #10 rollbacks."""
    report=json.loads((workspace/'artifacts/file-access-kernel-fix-verification.json').read_text())
    boot=workspace/'artifacts/boot-file-access-kernel-fix.img'
    assert report['runtime_verified'] and report['kernel_build_version']=='#11-postmarketOS'
    assert report['faccessat2_permissions_and_tablet_user_gio_passed']
    assert report['pidfd_status_ownership_error_checks_passed']
    assert report['libinput_himax_keyboard_touch_without_pointer']
    assert report['module_count']==37 and report['all_driver_modules_byte_identical']
    assert report['expected_installed_boot_sha256']=='27deb97480767c3420d97c88b599486abd1b86bbe297527a4e7a7bab61ccedd4'
    assert hashlib.sha256(boot.read_bytes()).hexdigest()==report['boot_sha256']=='30514abd03d82b8ade4fe1cb5f0698f30fcd54d56301111635bb51ad2f93147b'
    apk=workspace/'artifacts/apks'/report['kernel_package']
    assert hashlib.sha256(apk.read_bytes()).hexdigest()==report['kernel_package_sha256']
    return boot,report


def fingerprint(workspace: Path, ui: str) -> str:
    paths = [workspace / 'tools' / name for name in (
        'build-ui-variants.py', 'package-ui-recovery.py', 'verify-rootfs.py',
        'apply_ui_compat.py', 'ui_build_recipe.py', 'package-recovery.py')]
    paths += sorted((p for p in (workspace / 'ui-profiles').rglob('*') if p.is_file()),
                    key=lambda p: p.relative_to(workspace).as_posix())
    paths += [workspace/'port/camera-gta4l'/name for name in (
        'APKBUILD','gta4l-camera.py','gta4l-camera-service.py','gta4l-camera-run',
        'camera-hal-enumerate.c','camera-buffer.h')]
    paths += [workspace/'port/mesa-zink-kgsl-gta4l'/name for name in (
        'APKBUILD','zink-explicit-kgsl-device.patch','gta4l-zink-run')]
    for package in ('linux-samsung-gta4l','iio-sensor-proxy','modemmanager','gps-gta4l',
                    'gps-assistance-gta4l','camera-pipewire-gta4l','alsa-ucm-gta4l','snapshot'):
        paths += sorted((p for p in (workspace/'port'/package).iterdir() if p.is_file()),key=lambda p:p.name)
    digest = hashlib.sha256(ui.encode())
    for path in paths:
        digest.update(str(path.relative_to(workspace)).replace('\\', '/').encode() + b'\0')
        digest.update(path.read_bytes())
    return digest.hexdigest()
