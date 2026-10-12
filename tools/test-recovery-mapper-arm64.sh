#!/bin/busybox ash
# Only a sparse temporary image is attached; no physical partitions are used.
set -eu
export PATH=/bin
export LD_LIBRARY_PATH=/lib
. /gta4l-partition-functions.sh
image=/gta4l-loop-test.img
loop=''
attached=false
cleanup() {
    if [ "$attached" = true ]; then
        kpartx -d "$loop"
        losetup -d "$loop"
    fi
    rm -f "$image"
}
trap cleanup EXIT
gta4l_make_partition_table 4294967296 "$image"
loop="$(losetup -f)"
case "$loop" in /dev/loop[0-9]*) ;; *) exit 1;; esac
number="${loop#/dev/loop}"
case "$number" in ''|*[!0-9]*) exit 1;; esac
[ -b "$loop" ] || mknod "$loop" b 7 "$number"
losetup "$loop" "$image"
attached=true
backing="$(cat "/sys/class/block/loop$number/loop/backing_file")"
case "$backing" in /tmp/postmarketos/chroot/gta4l-loop-test.img|/gta4l-loop-test.img) ;; *) exit 1;; esac
kpartx -afs "$loop"
boot="/dev/mapper/$(basename "$loop")p1"
root="/dev/mapper/$(basename "$loop")p2"
[ -b "$boot" ] && [ -b "$root" ]
[ "$(blockdev --getsz "$boot")" = 522240 ]
[ "$(blockdev --getsz "$root")" = 7864320 ]
echo 'PASS: ARM64 kpartx creates both block nodes with correct sizes on a temporary loop image'
