#!/bin/sh
set -eu
echo '=== GPU boot and kernel state ==='
uname -a
cat /proc/uptime /proc/sys/kernel/random/boot_id
free -m
echo '=== GPU messages ==='
dmesg | grep -iE 'kgsl|adreno|gpu fault|gpu hang|out of memory|oom-kill' | tail -n 45 || true
echo GPU_HEALTH_CHECK_COMPLETE
