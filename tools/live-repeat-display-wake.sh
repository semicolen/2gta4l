#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
uname -a
xset +dpms
for seconds in 1 5 10; do
    printf 'GTA4L_REPEAT_WAKE: off for %s seconds\n' "$seconds" > /dev/kmsg
    timeout 5 xset dpms force off
    sleep "$seconds"
    timeout 5 xset dpms force on
    sleep 1
    echo "Completed off/on cycle: $seconds seconds off"
done
xset q | tail -n 8
dmesg | grep -Ei 'GTA4L_REPEAT|synchronous pre-LCD|LCD_LOG.*power_on|panic|BUG:' | tail -n 30
echo REPEAT_DISPLAY_WAKE_END
