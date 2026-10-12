#!/bin/sh
set -eu
backlight=/sys/class/backlight/panel0-backlight
brightness=$(cat "$backlight/brightness")
echo "Requested brightness: $brightness; max: $(cat "$backlight/max_brightness")"
printf '%s\n' "$brightness" > "$backlight/brightness"
echo "Actual brightness after update: $(cat "$backlight/actual_brightness")"
dmesg | tail -n 18
echo BACKLIGHT_REFRESH_END
