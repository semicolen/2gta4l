#!/bin/sh
set -u
echo '=== Post-resume backlight state ==='
for node in brightness actual_brightness bl_power; do
    printf '%s: ' "$node"
    cat /sys/class/backlight/panel0-backlight/$node
done
cat /sys/class/graphics/fb0/blank
printf '0' > /sys/class/backlight/panel0-backlight/bl_power
echo "Backlight power write status: $?"
printf '131' > /sys/class/backlight/panel0-backlight/brightness
echo "Post-resume brightness write status: $?"
dmesg | tail -n 80
echo POST_RESUME_BACKLIGHT_END
