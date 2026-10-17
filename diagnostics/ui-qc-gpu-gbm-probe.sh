#!/bin/sh
set -eu
test "$(id -u)" = 10000
printf '%s\n' '29ad9fb4803c01931d4b715e0f126c556c1b59a914b94d71ac57222f56f2cdce  /tmp/gta4l-upload/gpu-gbm-render-test' | sha256sum -c -
chmod 700 /tmp/gta4l-upload/gpu-gbm-render-test
XDG_RUNTIME_DIR=/run/user/10000 timeout 25 gta4l-zink-run /tmp/gta4l-upload/gpu-gbm-render-test
echo GPU_GBM_PROBE_COMPLETE
