#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
xrandr --verbose
echo '=== DRM module controls ==='
ls -l /sys/module/drm/parameters/ /sys/module/msm_drm/parameters/ 2>/dev/null
echo DISPLAY_PROPERTIES_END
