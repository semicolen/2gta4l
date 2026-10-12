#!/bin/sh
set -eu
for proc in /proc/[0-9]*; do
    cmd=$(tr '\000' ' ' < "$proc/cmdline" 2>/dev/null) || continue
    case "$cmd" in
        'python3 /tmp/gta4l-upload/gta4l-bt-initialize.py --probe'*)
            echo "PID=${proc##*/}"
            cat "$proc/wchan" "$proc/stack" || true
            kill -TERM "${proc##*/}"
            ;;
    esac
done
cat /sys/class/rfkill/rfkill0/soft
dmesg | tail -n 25
