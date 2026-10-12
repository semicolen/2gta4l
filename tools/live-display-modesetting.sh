stty -echo
printf '\nGTA4L_MODESETTING_BEGIN\n'
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
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
GTA4L_CONFIG_END
(
set -eu
rc-service lightdm stop
mount --bind /tmp/gta4l-modesetting.conf /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf
printf '<6>GTA4L_TEST: starting software DRM modesetting\n' > /dev/kmsg
rc-service lightdm start
)
printf '\nGTA4L_MODESETTING_END\n'
stty echo
