#!/bin/sh
set -eu
ROOT=/opt/gta4l-camera-dev/r0
mkdir -p "$ROOT/dev" "$ROOT/proc" "$ROOT/sys"
unshare -m /bin/sh -c '
    set -eu
    ROOT=/opt/gta4l-camera-dev/r0
    mount --make-rprivate /
    mount --bind /dev "$ROOT/dev"
    mount --bind /proc "$ROOT/proc"
    mount -o remount,bind,ro "$ROOT/proc"
    mount --bind /sys "$ROOT/sys"
    mount -o remount,bind,ro "$ROOT/sys"
    LD_LIBRARY_PATH=/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/apex/com.android.vndk.v31/lib64:/system/lib64 \
        timeout 12 chroot "$ROOT" /system/bin/camera-hal-enumerate --smoke
'
printf 'CAMERA_RUNTIME_SMOKE_WITH_DEV_END\n'
