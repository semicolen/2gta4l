#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
echo '=== X display power and mode ==='
xset q
xrandr --query
xfce4-screensaver-command --query
echo '=== Physical brightness and blanking ==='
for file in /sys/class/backlight/*/brightness /sys/class/backlight/*/actual_brightness /sys/class/backlight/*/bl_power /sys/class/graphics/fb0/blank; do
    [ -f "$file" ] || continue
    printf '%s: ' "$file"
    cat "$file"
done
echo '=== Latest panel messages ==='
dmesg | grep -Ei 'dsi|LCD_LOG|DRM blank|sde.*(fail|error)|FPS|backlight' | tail -n 75
echo DISPLAY_POWER_STATE_END
