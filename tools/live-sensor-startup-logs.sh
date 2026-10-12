#!/bin/sh
set -eu
tail -n 120 /var/log/gta4l/tqftpserv.log
find /vendor/etc -maxdepth 3 -iname '*sensor*' -o -iname '*registry*'
dmesg | grep -Ei 'sensor|ssc|registry|fastrpc|adsprpc' | tail -n 70
ls -l /dev/disk/by-partlabel/persist 2>/dev/null || true
echo SENSOR_STARTUP_LOGS_END
