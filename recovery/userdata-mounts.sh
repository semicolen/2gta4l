#!/sbin/sh
# Resolve mounts by device number, including aliases and nested bind mounts.
gta4l_userdata_mounts() {
    awk -v device_id="$1" '
        { paths[NR]=$5; devices[NR]=$3; if ($3 == device_id) roots[$5]=1 }
        END {
            for (i=1; i<=NR; i++) {
                selected=(devices[i] == device_id)
                for (root in roots)
                    if (index(paths[i], root "/") == 1) selected=1
                if (selected) print length(paths[i]), paths[i]
            }
        }' "$2" | sort -rn | cut -d ' ' -f 2-
}

gta4l_unmount_userdata() {
    data_id="$(cat /sys/class/block/mmcblk0p80/dev)" || return 1
    gta4l_unmount_mounts "$data_id" /proc/self/mountinfo
}

gta4l_unmount_mounts() {
    data_id="$1"
    mount_info="$2"
    mounts="$(gta4l_userdata_mounts "$data_id" "$mount_info")" || return 1
    # Recovery paths here have no whitespace. Refuse an encoded path rather
    # than risk unmounting a different target after decoding it incorrectly.
    case "$mounts" in *\\*) echo 'Unsupported escaped userdata mount path'; return 1;; esac
    if [ -n "$mounts" ]; then
        while IFS= read -r point; do
            echo "Unmounting userdata at $point"
            umount "$point" || return 1
        done <<EOF
$mounts
EOF
    fi
    awk -v device_id="$data_id" '$3 == device_id {found=1} END {exit found}' "$mount_info" || return 1
}
