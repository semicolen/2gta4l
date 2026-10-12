#!/bin/sh
set -eu
printf '=== Power supply names ===\n'
ls /sys/class/power_supply
printf '=== Diagnostic process wait states ===\n'
ps -eo pid,ppid,state,wchan:24,comm | grep -E 'python3|upower|cat|timeout' || true
printf '=== Recent kernel messages ===\n'
dmesg | tail -n 25
printf 'BATTERY_QUERY_STATE_END\n'
