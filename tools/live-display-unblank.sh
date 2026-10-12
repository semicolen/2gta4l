stty -echo
printf '\nGTA4L_UNBLANK_BEGIN\n'
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
xset s off
xset -dpms
xset dpms force on
printf '131\n' > /sys/class/backlight/panel0-backlight/brightness
printf '0\n' > /sys/class/graphics/fb0/blank
busybox setsid sh -c 'dd if=/dev/fb0 bs=4864 count=2000 2>/tmp/fb-capture.log | busybox nc -l -p 2426' </dev/null >/tmp/fb-server.log 2>&1 &
echo "Framebuffer capture listener PID $!"
printf '\nGTA4L_UNBLANK_END\n'
stty echo
