#!/bin/sh
set -eu
ROOT=/opt/gta4l-camera-dev/r0
mkdir -p "$ROOT/dev" "$ROOT/proc" "$ROOT/sys"
mkdir -p "$ROOT/data/vendor/camera" "$ROOT/data/misc/camera" "$ROOT/data/vendor/camera/cache"
chmod 700 "$ROOT/data/vendor/camera" "$ROOT/data/misc/camera" "$ROOT/data/vendor/camera/cache"
unshare -m /bin/sh -c '
    set -eu
    ROOT=/opt/gta4l-camera-dev/r0
    mount --make-rprivate /
    mount --bind /dev "$ROOT/dev"
    mount --bind /proc "$ROOT/proc"
    mount -o remount,bind,ro "$ROOT/proc"
    mount --bind /sys "$ROOT/sys"
    mount -o remount,bind,ro "$ROOT/sys"
    # request_firmware() resolves paths from the camera process root. Expose
    # the already-installed matching GPU firmware read-only in this namespace.
    mkdir -p "$ROOT/lib/firmware" "$ROOT/usr/lib/firmware"
    mount --bind /usr/lib/firmware "$ROOT/lib/firmware"
    mount -o remount,bind,ro "$ROOT/lib/firmware"
    mount --bind /usr/lib/firmware "$ROOT/usr/lib/firmware"
    mount -o remount,bind,ro "$ROOT/usr/lib/firmware"
    LD_LIBRARY_PATH=/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/vendor/lib64/hw:/apex/com.android.vndk.v31/lib64:/system/lib64 \
        timeout 25 chroot "$ROOT" /system/bin/camera-hal-enumerate --buffer-check
'
printf 'CAMERA_HAL_ISOLATED_TEST_END\n'
