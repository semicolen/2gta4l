#!/usr/bin/env bash
# Test the nested MBR and two filesystems on a disposable WSL loop device.
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
NATIVE="$ROOT/work/chroot_native"
TEST_DIR="$(mktemp -d "$NATIVE/tmp/gta4l-installer-test.XXXXXX")"
TEST_PATH="${TEST_DIR#"$NATIVE"}"
LOOP=''
INNER=''
cleanup() {
    mountpoint -q "$TEST_DIR/mount/boot" && umount "$TEST_DIR/mount/boot" || true
    mountpoint -q "$TEST_DIR/mount" && umount "$TEST_DIR/mount" || true
    if [ -n "$INNER" ]; then kpartx -d "$INNER" || true; fi
    if [ -n "$LOOP" ]; then losetup -d "$LOOP" || true; fi
    case "$TEST_DIR" in "$NATIVE"/tmp/gta4l-installer-test.*) rm -rf -- "$TEST_DIR";; *) exit 1;; esac
}
trap cleanup EXIT
cp "$WORKSPACE/recovery/partition-functions.sh" "$TEST_DIR/functions.sh"
chroot "$NATIVE" /bin/sh -c '. "$1"; gta4l_make_partition_table 4294967296 "$2"' test "$TEST_PATH/functions.sh" "$TEST_PATH/inner.img"
# Outer disk represents Samsung eMMC; only its userdata subpartition is changed.
truncate -s $((4294967296 + 2 * 1048576)) "$TEST_DIR/outer.img"
chroot "$NATIVE" parted -s "$TEST_PATH/outer.img" mklabel gpt
chroot "$NATIVE" parted -s "$TEST_PATH/outer.img" mkpart userdata 2048s 8390655s
LOOP="$(losetup --find --show --partscan "$TEST_DIR/outer.img")"
INNER="${LOOP}p1"
[ -b "$INNER" ]
[ "$(blockdev --getsize64 "$INNER")" = 4294967296 ]
dd if="$TEST_DIR/outer.img" of="$TEST_DIR/outer-gpt-before" bs=512 count=2048 status=none
dd if=/dev/zero of="$INNER" bs=4096 count=256 conv=fsync status=none
dd if="$TEST_DIR/inner.img" of="$INNER" bs=512 count=1 conv=fsync status=none
kpartx -afs "$INNER"
BOOT="/dev/mapper/$(basename "$INNER")p1"
DATA="/dev/mapper/$(basename "$INNER")p2"
[ -b "$BOOT" ] && [ -b "$DATA" ]
[ "$(blockdev --getsz "$BOOT")" = 522240 ]
[ "$(blockdev --getsz "$DATA")" = 7864320 ]
mkfs.ext2 -q -L pmOS_boot "$BOOT"
mkfs.ext4 -q -O '^metadata_csum,^huge_file' -L pmOS_root "$DATA"
mkdir "$TEST_DIR/mount"
mount "$DATA" "$TEST_DIR/mount"
mkdir "$TEST_DIR/mount/boot"
mount "$BOOT" "$TEST_DIR/mount/boot"
printf 'nested root filesystem verified\n' > "$TEST_DIR/mount/probe"
printf 'nested boot filesystem verified\n' > "$TEST_DIR/mount/boot/probe"
sync
umount "$TEST_DIR/mount/boot"
umount "$TEST_DIR/mount"
dd if="$TEST_DIR/outer.img" of="$TEST_DIR/outer-gpt-after" bs=512 count=2048 status=none
cmp "$TEST_DIR/outer-gpt-before" "$TEST_DIR/outer-gpt-after"
echo 'PASS: sparse MBR, nested block mappings, ext2/ext4 format and mount; outer GPT unchanged'
