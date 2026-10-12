#!/bin/sh
set -eu
printf '%s\n' 'e9c08f0ac14ca0af73af42dc17cd096b3f25d80099a59f3385b11b130df3aab5  /tmp/gta4l-upload/mesa-vulkan-kgsl-gta4l-26.2.4-r0.apk' | sha256sum -c -
printf '%s\n' '371877995bb45e15e82f8e0d59f609a62f2a26c2f98776cae3c1a1853838828d  /tmp/gta4l-upload/xcb-util-keysyms-0.4.1-r0.apk' '7dd23f3055b9b747380c4c629c3a0bc3b163def64df4df97e1b1bee9d7e641f2  /tmp/gta4l-upload/vulkan-loader-1.4.360-r0.apk' | sha256sum -c -
apk --no-network --no-interactive --no-scripts add \
    /tmp/gta4l-upload/xcb-util-keysyms-0.4.1-r0.apk \
    /tmp/gta4l-upload/vulkan-loader-1.4.360-r0.apk \
    /tmp/gta4l-upload/mesa-vulkan-kgsl-gta4l-26.2.4-r0.apk
cat /usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
ls -l /usr/lib/gta4l-kgsl/libvulkan_freedreno.so /usr/lib/libvulkan.so* 2>/dev/null || true
echo KGSL_INSTALL_END
