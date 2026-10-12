#!/bin/sh
set -u
echo '=== Firmware and touch resume logs ==='
uptime
dmesg | grep -Ei 'HXTP|firmware|panel|dsi' | tail -n 100
echo '=== Firmware names ==='
find /lib/firmware -maxdepth 3 -type f | grep -Ei 'himax|hx|inx|fhd' | head -n 35
echo '=== Firmware pending requests ==='
ls -l /sys/class/firmware/ 2>/dev/null || true
echo '=== Touch command state ==='
cat /sys/class/sec/tsp/cmd_status /sys/class/sec/tsp/cmd_result /proc/android_touch/SMWP 2>/dev/null
echo RESUME_FIRMWARE_LOGS_END
