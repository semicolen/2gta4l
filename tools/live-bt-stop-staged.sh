#!/bin/sh
set -eu
pid=$(cat /run/gta4l-bt-test.pid)
case "$pid" in ''|*[!0-9]*) exit 1;; esac
if [ -e "/proc/$pid/cmdline" ]; then
    tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q '^python3 /tmp/gta4l-upload/gta4l-bt-initialize.py'
    kill -TERM "$pid"
    sleep 1
fi
[ ! -e "/proc/$pid" ] || [ "$(awk '/^State:/ {print $2}' "/proc/$pid/status")" = Z ]
rm /run/gta4l-bt-test.pid
bluetoothctl list
cat /sys/class/rfkill/rfkill0/soft
echo BT_STAGED_TRANSPORT_STOPPED
