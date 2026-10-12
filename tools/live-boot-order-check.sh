#!/bin/sh
set -eu
echo '=== Startup dependency order ==='
/usr/libexec/rc/bin/rc-depend -u -a -s gta4l-dbus-services elogind networkmanager lightdm
echo '=== Barrier edges ==='
grep -E 'gta4l-dbus-services|modemmanager|polkit' /run/openrc/deptree
echo BOOT_ORDER_CHECK_END
