#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
python3 - <<'PY'
import gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
root = Gdk.get_default_root_window()
width, height = root.get_width(), root.get_height()
image = Gdk.pixbuf_get_from_window(root, 0, 0, width, height)
image.savev('/tmp/gta4l-rotation-desktop.png', 'png', [], [])
print(f'Saved X root screenshot: {width}x{height}')
PY
