#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
[ -s "$XAUTHORITY" ]
uname -a
echo '=== Backlight write with newline ==='
python3 - <<'PY'
import os
path = '/sys/class/backlight/panel0-backlight/brightness'
for value in [b'131\n', b'131']:
    fd = os.open(path, os.O_WRONLY)
    try:
        print('Brightness write:', repr(value), 'returned', os.write(fd, value), flush=True)
    except OSError as error:
        print('Brightness write error:', error, flush=True)
    finally:
        os.close(fd)
PY
echo '=== Deliberate DPMS cycle ==='
xset dpms force off
sleep 3
xset dpms force on
sleep 2
xset q | tail -n 8
cat /sys/class/backlight/panel0-backlight/brightness
dmesg | grep -Ei 'dsi|LCD_LOG|DRM blank|backlight' | tail -n 50
echo BACKLIGHT_RESUME_TEST_END
