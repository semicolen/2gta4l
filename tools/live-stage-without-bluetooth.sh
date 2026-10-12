stty -echo
printf '\nGTA4L_BT_PAUSE_SETUP_BEGIN\n'
cat > /hooks-cleanup/101-gta4l-pause-bluetooth.sh <<'GTA4L_HOOK_END'
set -eu
source=/sysroot/etc/runlevels/default
target=/tmp/gta4l-default-without-bluetooth
[ -L "$source/bluetooth" ]
mkdir -p "$target"
for service in "$source"/*; do
    [ "${service##*/}" = bluetooth ] || cp -a "$service" "$target/"
done
mount -o bind "$target" "$source"
echo 'SM-T505 diagnostic: Bluetooth paused for this boot while the HCI kernel fix builds'
GTA4L_HOOK_END
printf '\nGTA4L_BT_PAUSE_SETUP_END\n'
stty echo
