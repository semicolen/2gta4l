stty -echo
printf '\nGTA4L_DISPLAY_RETRY_BEGIN\n'
(
set -eu
printf '%s\n' '3d6a948bd578a0d9aaefd3a5c0d9471fdce914a8a1eb65b83d38b6583d0ee62e  /tmp/bwrap-gta4l' | sha256sum -c -
chmod 755 /tmp/bwrap-gta4l
su -s /bin/sh lightdm -c '/usr/bin/bwrap --unshare-all --die-with-parent --ro-bind /usr /usr --dev /dev --symlink usr/lib /lib --symlink usr/bin /bin --tmpfs /tmp --chdir / /usr/bin/busybox true'
echo 'Sandbox test passed as the login greeter user'
rc-service lightdm stop
rc-service lightdm start
)
printf '\nGTA4L_DISPLAY_RETRY_END\n'
stty echo
