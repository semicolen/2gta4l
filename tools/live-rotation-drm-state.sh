#!/bin/sh
set -eu
cat /sys/kernel/debug/dri/0/state 2>/dev/null || true
cat /sys/kernel/debug/dri/0/disp_info 2>/dev/null || true
dmesg | grep -Ei 'drm|sde|smmu|dsi|rotation|atomic' | tail -n 60
echo ROTATION_DRM_STATE_END
