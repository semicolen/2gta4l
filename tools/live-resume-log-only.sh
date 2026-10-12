#!/bin/sh
set -u
uptime
ps -eo pid,ppid,stat,comm,args | grep -E 'cat|himax|ssh|firmware' | head -n 40
dmesg | grep -Ei 'HXTP|firmware|panel|dsi' | tail -n 65
find /lib/firmware -maxdepth 3 -type f | grep -Ei 'himax|hx|inx|fhd' | head -n 35
ls -l /sys/class/firmware/ 2>/dev/null || true
echo RESUME_LOG_ONLY_END
