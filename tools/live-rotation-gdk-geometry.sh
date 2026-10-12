#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
apk list --installed xfce4-screensaver gtk+3.0
xrandr --listmonitors
python3 - <<'PY'
import gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
display = Gdk.Display.get_default()
for n in range(display.get_n_monitors()):
    monitor = display.get_monitor(n)
    geo = monitor.get_geometry()
    area = monitor.get_workarea()
    print('GDK_MONITOR', n, 'geometry', geo.x, geo.y, geo.width, geo.height,
          'workarea', area.x, area.y, area.width, area.height)
PY
echo GDK_GEOMETRY_END
