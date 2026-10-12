#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
export XDG_RUNTIME_DIR=/run/user/10000
# Use Mesa's CPU presentation path while retaining the hardware Vulkan device.
export MESA_VK_WSI_DEBUG=sw
echo '=== Adreno render with X11 copy presentation ==='
timeout 20 vkcube --wsi xlib --c 300 --width 800 --height 800 --suppress_popups
status=$?
echo "X11 copy cube exit: $status"
echo VKCUBE_X11_COPY_END
exit "$status"
