stty -echo
printf '\nGTA4L_BWRAP_DISPLAY_BEGIN\n'
(
set -eu
/tmp/bwrap-gta4l --unshare-all --die-with-parent --ro-bind /usr /usr --dev /dev --symlink usr/lib /lib --symlink usr/bin /bin --symlink usr/sbin /sbin --tmpfs /tmp --chdir / /usr/bin/busybox true
echo 'Compatible sandbox test passed'
[ -f /usr/bin/bwrap ]
mount -o bind /tmp/bwrap-gta4l /usr/bin/bwrap
echo 'Compatible Bubblewrap bound for this boot only'
rc-service lightdm start
)
printf '\nGTA4L_BWRAP_DISPLAY_END\n'
stty echo
