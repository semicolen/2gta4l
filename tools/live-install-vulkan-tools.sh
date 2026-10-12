#!/bin/sh
set -eu
printf '%s\n' 'bda0574c4849691949780f8e49893ca67352fd170c85ac426f681db7331baba5  /tmp/gta4l-upload/vulkan-tools-gta4l-1.4.360-r0.apk' | sha256sum -c -
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/vulkan-tools-gta4l-1.4.360-r0.apk
echo VULKAN_TOOLS_INSTALL_END
