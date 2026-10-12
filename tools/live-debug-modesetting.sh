stty -echo
printf '\nGTA4L_XORG_GDB_BEGIN\n'
cat > /tmp/gta4l-modesetting.conf <<'GTA4L_CONFIG_END'
Section "Device"
    Identifier "SM-T505 framebuffer"
    Driver "modesetting"
    Option "kmsdev" "/dev/dri/card0"
    Option "AccelMethod" "none"
    Option "SWcursor" "true"
    Option "ShadowFB" "true"
    Option "PageFlip" "false"
EndSection
GTA4L_CONFIG_END
(
set -eu
rc-service lightdm stop
mount --bind /tmp/gta4l-modesetting.conf /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf
printf '<6>GTA4L_TEST: debugger starting software DRM modesetting\n' > /dev/kmsg
LD_LIBRARY_PATH=/tmp/gta4l-gdb/lib /tmp/gta4l-gdb/bin/gdb -nx -nh -batch \
    -ex 'set auto-load off' -ex 'set pagination off' \
    -ex 'handle SIGUSR1 nostop noprint pass' -ex run \
    -ex bt -ex 'thread apply all bt' -ex 'info sharedlibrary' \
    --args /usr/libexec/Xorg :1 -nolisten tcp vt7 -novtswitch
umount /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf
rc-service lightdm start
) </dev/null >/var/log/gta4l/hci-fix-Xorg-modesetting-gdb.log 2>&1 &
echo "Xorg debugger task: $!"
printf '\nGTA4L_XORG_GDB_END\n'
stty echo
