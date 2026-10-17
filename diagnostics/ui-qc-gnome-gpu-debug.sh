#!/bin/sh
set -u
test "$(id -u)" = 10000 || exit 1
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== User access ==='
id
echo '=== Loader diagnostics ==='
EGL_LOG_LEVEL=debug LIBGL_DEBUG=verbose MESA_DEBUG=1 VK_LOADER_DEBUG=error,warn timeout 25 gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware
echo "SHADER_EXIT=$?"
echo '=== Vulkan device ==='
VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json timeout 20 vulkaninfo --summary
echo "VULKAN_EXIT=$?"
