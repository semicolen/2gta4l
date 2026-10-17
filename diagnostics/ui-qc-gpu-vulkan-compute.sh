#!/bin/sh
set -eu
test "$(id -u)" = 10000
sha256sum -c - <<'CHECKSUMS'
4176ebf54c61b319c26413196219d921d9532a0ac6dabc08b6abc3b3b0ce6c9f  /tmp/gta4l-upload/gpu-compute-test
cd4ee9a347b7b4718c0d818bbd3c383442eb277a78b92c29c8652bc6007dd7af  /tmp/gta4l-upload/gpu-compute.spv
CHECKSUMS
chmod 700 /tmp/gta4l-upload/gpu-compute-test
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
timeout 20 /tmp/gta4l-upload/gpu-compute-test /tmp/gta4l-upload/gpu-compute.spv
echo GPU_VULKAN_COMPUTE_COMPLETE
