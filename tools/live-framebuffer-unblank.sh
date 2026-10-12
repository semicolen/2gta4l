#!/bin/sh
set -u
echo '=== Console state ==='
cat /sys/class/tty/tty0/active
cat /sys/module/kernel/parameters/consoleblank
echo '=== Framebuffer unblank ==='
printf '0\n' > /sys/class/graphics/fb0/blank
echo "Framebuffer unblank exit: $?"
printf '131' > /sys/class/backlight/panel0-backlight/brightness
echo "Brightness write without newline exit: $?"
dmesg | grep -Ei 'dsi|LCD_LOG|DRM blank|backlight' | tail -n 16
echo FRAMEBUFFER_UNBLANK_END
