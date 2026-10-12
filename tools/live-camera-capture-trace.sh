#!/bin/sh
set -eu
ROOT=/opt/gta4l-camera-dev/r0
unshare -m /bin/sh -c '
    set -eu
    ROOT=/opt/gta4l-camera-dev/r0
    mount --make-rprivate /
    mount --bind /dev "$ROOT/dev"
    mount --bind /proc "$ROOT/proc"
    mount -o remount,bind,ro "$ROOT/proc"
    mount --bind /sys "$ROOT/sys"
    mount -o remount,bind,ro "$ROOT/sys"
    printf "KGSL_VISIBLE_IN_CHROOT="
    test -c "$ROOT/dev/kgsl-3d0" && printf "yes\n" || printf "no\n"
    LD_LIBRARY_PATH=/tmp/gta4l-trace/lib:/apex/com.android.runtime/lib64/bionic:/vendor/lib64:/vendor/lib64/hw:/apex/com.android.vndk.v31/lib64:/system/lib64 \
        timeout 22 /tmp/gta4l-trace/bin/strace -f -e trace=openat,ioctl,mmap \
        -o "$ROOT/capture.strace" chroot "$ROOT" /system/bin/camera-hal-enumerate --capture-check || true
'
python3 - <<'PY'
from pathlib import Path
p=Path('/opt/gta4l-camera-dev/r0/capture.strace')
lines=p.read_text(errors='replace').splitlines()
print('TRACE_LINES='+str(len(lines)))
for line in lines:
    if 'kgsl' in line or 'SIGSEGV' in line or ('openat(' in line and '/dev/' in line and '= -1' in line):
        print(line)
print('\n'.join(lines[-12:]))
PY
