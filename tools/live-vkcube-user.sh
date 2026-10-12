#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Hardware Vulkan graphics and X11 presentation ==='
timeout 20 vkcube --wsi xlib --c 300 --suppress_popups
status=$?
echo "Hardware cube exit: $status"
echo VKCUBE_USER_END
exit "$status"
