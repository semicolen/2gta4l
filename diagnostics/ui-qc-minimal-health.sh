#!/bin/sh
set -eu
uname -a
cat /proc/sys/kernel/random/boot_id
cat /proc/uptime
cat /proc/loadavg
cat /proc/meminfo | head -n 6
echo USB_SSH_HEALTH_OK
