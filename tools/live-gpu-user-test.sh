#!/bin/sh
set -eu
id
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
timeout 20 /tmp/gta4l-upload/gpu-compute-test /tmp/gta4l-upload/gpu-compute.spv
echo GPU_USER_TEST_END
