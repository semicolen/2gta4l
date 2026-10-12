#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Vulkan summary ==='
timeout 15 vulkaninfo --summary
echo "Vulkan summary exit: $?"
echo '=== Cube options ==='
vkcube --help 2>&1 | tail -n 26
echo VULKAN_SUMMARY_END
