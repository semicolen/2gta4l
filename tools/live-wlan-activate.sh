#!/bin/sh
set -eu
[ -c /dev/wlan ]
[ ! -e /run/gta4l-wlan-start.pid ]
echo 'GTA4L_TEST: WLAN activation after downstream TQFTP repair' > /dev/kmsg
nohup timeout -k 5 30 sh -c '
    printf "ON\n" > /dev/wlan
    echo "WLAN ON command completed"
    ip -br link
' </dev/null >/var/log/gta4l/wlan-tqftp-start.log 2>&1 &
echo "$!" > /run/gta4l-wlan-start.pid
echo "Started bounded WLAN activation task: $!"
