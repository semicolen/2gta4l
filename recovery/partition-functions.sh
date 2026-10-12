# SM-T505 internal userdata contains a nested MBR for pmOS_boot + pmOS_root.
# Build the MBR on a sparse regular file. Running parted directly on an eMMC
# partition asks the recovery kernel to reread the whole eMMC partition table.

gta4l_make_partition_table() {
    table_bytes="$1"
    table_file="$2"
    [ "$table_bytes" -ge 4294967296 ] && [ "$table_bytes" -lt 2199023255552 ] || return 1
    [ $((table_bytes % 512)) -eq 0 ] || return 1
    [ ! -L "$table_file" ] || return 1
    table_sectors=$((table_bytes / 512))
    root_end=$((table_sectors / 2048 * 2048 - 1))
    truncate -s 0 "$table_file" || return 1
    truncate -s "$table_bytes" "$table_file" || return 1
    parted -s "$table_file" mklabel msdos || return 1
    parted -s "$table_file" mkpart primary ext2 2048s 524287s || return 1
    parted -s "$table_file" mkpart primary ext4 524288s "${root_end}s" || return 1
    parted -s "$table_file" set 1 boot on || return 1
    table_layout="$(parted -m -s "$table_file" unit s print)" || return 1
    printf '%s\n' "$table_layout" | awk -F: -v root_end="$root_end" '
        $1 == "1" && $2 == "2048s" && $3 == "524287s" && $4 == "522240s" && $7 == "boot;" {boot++}
        $1 == "2" && $2 == "524288s" && $3 == (root_end "s") && $4 == ((root_end-524288+1) "s") {root++}
        /^[0-9]+:/ {count++}
        END {exit !(boot == 1 && root == 1 && count == 2)}' || return 1
}

gta4l_assert_userdata_idle() {
    data_id="$(cat /sys/class/block/mmcblk0p80/dev)" || return 1
    # /proc/self hides recovery mounts outside this chroot. PID 1 retains
    # OrangeFox's root and exposes the actual /data and /sdcard mounts.
    awk -v device_id="$data_id" '$3 == device_id {found=1} END {exit found}' /proc/1/mountinfo || {
        ui_print 'Userdata is still mounted. Unmount Data in OrangeFox and retry.'
        return 1
    }
    for holder in /sys/class/block/mmcblk0p80/holders/*; do
        [ ! -e "$holder" ] || {
            ui_print 'Userdata has an active block mapping. Restart OrangeFox and retry.'
            return 1
        }
    done
}

# Override the upstream function, which ignores partitioning and mapping errors.
partition_install_device() {
    [ "$INSTALL_PARTITION" = userdata ] && [ "$INSTALL_DEVICE" = /dev/block/mmcblk0p80 ] &&
        [ "$BOOT_PARTITION" = /dev/block/mmcblk0p69 ] && [ "$ISOREC" = false ] && [ "$FDE" = false ] || return 1
    gta4l_assert_userdata_idle || return 1
    [ "$(blockdev --getss "$INSTALL_DEVICE")" = 512 ] || return 1
    data_bytes="$(blockdev --getsize64 "$INSTALL_DEVICE")" || return 1
    gta4l_make_partition_table "$data_bytes" /pmos-partition-table.img || return 1
    # Check again immediately before the first device write.
    gta4l_assert_userdata_idle || return 1
    dd if=/pmos-partition-table.img of=/pmos-mbr-expected bs=512 count=1 || return 1
    # Clear Android's primary/backup superblocks in the reserved 1 MiB gap.
    # Otherwise OrangeFox could still recognize and mount the old f2fs volume.
    dd if=/dev/zero of="$INSTALL_DEVICE" bs=4096 count=256 conv=fsync || return 1
    dd if=/pmos-mbr-expected of="$INSTALL_DEVICE" bs=512 count=1 conv=fsync || return 1
    dd if="$INSTALL_DEVICE" of=/pmos-mbr-readback bs=512 count=1 || return 1
    cmp /pmos-mbr-expected /pmos-mbr-readback || return 1
    # No global partprobe: the outer Samsung GPT must remain untouched.
    kpartx -afs "$INSTALL_DEVICE" || return 1
    set_subpartitions
    [ -b "$PMOS_BOOT" ] && [ -b "$ROOT_PARTITION" ] || return 1
    [ "$(blockdev --getsz "$PMOS_BOOT")" = 522240 ] || return 1
    [ "$(blockdev --getsz "$ROOT_PARTITION")" = "$((root_end - 524288 + 1))" ] || return 1
}
