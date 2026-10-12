#!/bin/sh
set -eu
[ -c /dev/ion ]
cat > /etc/udev/rules.d/79-gta4l-ion.rules <<'EOF'
# The downstream Vulkan driver's external memory uses ION.
ACTION=="add|change", SUBSYSTEM=="misc", KERNEL=="ion", GROUP="video", MODE="0660"
EOF
udevadm control --reload-rules
udevadm trigger --action=change --sysname-match=ion
udevadm settle --timeout=5
ls -l /dev/ion
echo ION_PERMISSIONS_TEST_END
