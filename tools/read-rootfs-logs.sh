#!/system/bin/sh
# Read the nested root filesystem without replaying its journal.
set -eu
start="$1"
length="$2"
data=/dev/block/mmcblk0p80
[ "$(readlink -f /dev/block/by-name/userdata)" = "$data" ]
[ "$start" = 268435456 ]
case "$length" in ''|*[!0-9]*) exit 1;; esac
bytes="$(blockdev --getsize64 "$data")"
[ "$length" -gt 0 ] && [ "$((start + length))" -le "$bytes" ]
loop=''
attached=false
mounted=false
root=/tmp/gta4l-root-readonly
out=/tmp/gta4l-bootloop-evidence
cleanup() {
    [ "$mounted" = false ] || umount "$root"
    if [ "$attached" = true ] && losetup "$loop" >/dev/null 2>&1; then
        losetup -d "$loop"
    fi
}
trap cleanup EXIT
mkdir -p "$root" "$out"
loop="$(losetup -f)"
case "$loop" in /dev/block/loop[0-9]*|/dev/loop[0-9]*) ;; *) exit 1;; esac
losetup -r -o "$start" -S "$length" "$loop" "$data"
attached=true
[ "$(blockdev --getro "$loop")" = 1 ]
mount -t ext4 -o ro,noload "$loop" "$root"
mounted=true
cat "$root/etc/os-release" > "$out/os-release.txt"
ls -l "$root/var/log" > "$out/log-files.txt"
tar -czf "$out/var-log.tar.gz" -C "$root" var/log
for name in boot dmesg messages rc.log; do
    if [ -f "$root/var/log/$name" ]; then
        cp "$root/var/log/$name" "$out/$name.txt"
    fi
done
if [ -d "$root/var/log/gta4l" ]; then
    mkdir -p "$out/gta4l"
    cp -R "$root/var/log/gta4l/." "$out/gta4l/"
fi
ls -l "$root/etc/runlevels" "$root/etc/runlevels/default" > "$out/services.txt"
echo 'Collected root filesystem logs through a read-only loop device (ro,noload)'
