stty -echo
printf '\nGTA4L_ROOTLOGS_BEGIN\n'
(
    set -eu
    [ "$(blockdev --getsize64 /dev/mmcblk0p80)" = 23484415488 ]
    ! mountpoint -q /sysroot
    mkdir -p /tmp/gta4l-root-readonly
    loop="$(losetup -f)"
    attached=false
    mounted=false
    cleanup() { [ "$mounted" = false ] || umount /tmp/gta4l-root-readonly; if [ "$attached" = true ] && losetup "$loop" >/dev/null 2>&1; then losetup -d "$loop"; fi; }
    trap cleanup EXIT
    losetup -r -o 268435456 "$loop" /dev/mmcblk0p80
    attached=true
    [ "$(blockdev --getro "$loop")" = 1 ]
    [ "$(blockdev --getsize64 "$loop")" = 23215980032 ]
    mount -t ext4 -o ro,noload "$loop" /tmp/gta4l-root-readonly
    mounted=true
    tar -czf /tmp/gta4l-rootlogs.tar.gz -C /tmp/gta4l-root-readonly var/log
    umount /tmp/gta4l-root-readonly
    mounted=false
    if losetup "$loop" >/dev/null 2>&1; then losetup -d "$loop"; fi
    attached=false
    printf '\nGTA4L_FILE:/tmp/gta4l-rootlogs.tar.gz\n'
    sha256sum /tmp/gta4l-rootlogs.tar.gz
    base64 /tmp/gta4l-rootlogs.tar.gz
    printf '\nGTA4L_FILE_END\n'
)
printf '\nGTA4L_TRANSFER_END\n'
stty echo
