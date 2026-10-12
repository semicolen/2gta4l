#!/bin/sh
set -eu
printf '%s\n' '4176ebf54c61b319c26413196219d921d9532a0ac6dabc08b6abc3b3b0ce6c9f  /tmp/gta4l-upload/gpu-compute-test' 'cd4ee9a347b7b4718c0d818bbd3c383442eb277a78b92c29c8652bc6007dd7af  /tmp/gta4l-upload/gpu-compute.spv' | sha256sum -c -
chmod 755 /tmp/gta4l-upload/gpu-compute-test
echo 'GTA4L_TEST: isolated Turnip KGSL GPU compute' > /dev/kmsg
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
export VK_LOADER_DEBUG=error,warn
set +e
timeout 20 /tmp/gta4l-upload/gpu-compute-test /tmp/gta4l-upload/gpu-compute.spv > /var/log/gta4l/gpu-compute-root.log 2>&1
status=$?
cat /var/log/gta4l/gpu-compute-root.log
echo "GPU workload exit: $status"
dmesg | grep -Ei 'kgsl|adreno|a610|gpu|zap' | tail -n 45
echo GPU_COMPUTE_TEST_END
exit "$status"
