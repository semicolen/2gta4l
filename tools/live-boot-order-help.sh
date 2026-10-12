#!/bin/sh
set -eu
cat /etc/init.d/gta4l-dbus-services
echo '=== Dependency utility options ==='
/usr/libexec/rc/bin/rc-depend --help
echo BOOT_ORDER_HELP_END
