#!/bin/sh
set -eu
/root/gta4l-gpu-qc-backup/gnome-session-before/rollback.sh
echo '=== GPU node permissions ==='
ls -l /dev/kgsl-3d0 /dev/ion /dev/dri/*
echo '=== Installed GPU packages ==='
apk --no-network info -v | grep -E '^(mesa|vulkan|libdrm|libepoxy|linux-samsung)'
echo '=== Current kernel ==='
uname -a
