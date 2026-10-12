#!/system/bin/sh
# Update Linux package contents without invoking boot generation or formatting.
set -eu
data=/dev/block/mmcblk0p80
root=/tmp/gta4l-root-update
root_loop=''
boot_loop=''
root_mounted=false
boot_mounted=false
cleanup() {
    [ "$boot_mounted" = false ] || umount "$root/boot"
    [ "$root_mounted" = false ] || umount "$root"
    if [ -n "$boot_loop" ] && losetup "$boot_loop" >/dev/null 2>&1; then losetup -d "$boot_loop"; fi
    if [ -n "$root_loop" ] && losetup "$root_loop" >/dev/null 2>&1; then losetup -d "$root_loop"; fi
}
trap cleanup EXIT
[ "$(getprop ro.product.device)" = gta4l ]
[ "$(readlink -f /dev/block/by-name/userdata)" = "$data" ]
[ "$(blockdev --getsize64 "$data")" = 23484415488 ]
sha256sum -c /tmp/gta4l-package-update.sha256
mkdir -p "$root"
root_loop="$(losetup -f)"
losetup -o 268435456 -S 23215980032 "$root_loop" "$data"
[ "$(dd if="$root_loop" bs=1 skip=1144 count=16 2>/dev/null | tr -d '\000')" = pmOS_root ]
mount -t ext4 "$root_loop" "$root"
root_mounted=true
boot_loop="$(losetup -f)"
losetup -o 1048576 -S 267386880 "$boot_loop" "$data"
[ "$(dd if="$boot_loop" bs=1 skip=1144 count=16 2>/dev/null | tr -d '\000')" = pmOS_boot ]
mount -t ext4 "$boot_loop" "$root/boot"
boot_mounted=true
mkdir -p "$root/tmp/gta4l-package-update"
cp /tmp/gta4l-package-update/*.apk "$root/tmp/gta4l-package-update/"
# Scripts and triggers would regenerate boot and remove the diagnostic setup.
chroot "$root" /sbin/apk --no-network --no-interactive --no-scripts add /tmp/gta4l-package-update/*.apk
sha256sum "$root/boot/vmlinuz"
awk '/^P:/{wanted=($0 ~ /^P:(linux-samsung-gta4l|device-samsung-gta4l|bubblewrap-gta4l)$/); name=$0} wanted && /^V:/{print name,$0}' "$root/lib/apk/db/installed"
sync
echo 'Installed kernel and device packages without boot scripts; no formatting'
