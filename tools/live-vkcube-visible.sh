#!/bin/sh
set -eu
[ "$(id -u)" = 10000 ]
pgrep -u 10000 -x xfce4-session >/dev/null
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
export XDG_RUNTIME_DIR=/run/user/10000
export MESA_VK_WSI_DEBUG=sw
mkdir -p /home/tablet/.cache/gta4l
log=/home/tablet/.cache/gta4l/vkcube-visible.log
nohup timeout 60 vkcube --wsi xlib --width 800 --height 800 --suppress_popups \
    </dev/null >"$log" 2>&1 &
pid=$!
echo "$pid" > /home/tablet/.cache/gta4l/vkcube-visible.pid
sleep 2
kill -0 "$pid"
cat "$log"
echo "Vulkan cube is running with timeout PID $pid; it will close after 60 seconds."
echo VKCUBE_VISIBLE_START_END
