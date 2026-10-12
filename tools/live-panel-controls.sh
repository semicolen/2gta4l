#!/bin/sh
set -u
echo '=== Touch command nodes ==='
find /sys/class/sec -maxdepth 3 -type f -name 'cmd*' -o -name '*gesture*' -o -name '*double*' 2>/dev/null
ls -l /sys/class/sec /sys/class/sec/tsp/ 2>/dev/null
echo '=== Runtime panel controls ==='
ls -l /sys/class/graphics/fb0/ /sys/class/drm/card0-DSI-1/ /sys/devices/platform/soc/soc:qcom,dsi-display-primary/ 2>/dev/null
echo '=== Touch firmware logs ==='
dmesg | grep -Ei 'hx83102|reset|gpio|touch|master|client' | tail -n 60
echo PANEL_CONTROLS_END
