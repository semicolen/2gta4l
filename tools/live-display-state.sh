stty -echo
printf '\nGTA4L_DISPLAY_STATE_BEGIN\n'
uname -a
cat /proc/uptime
rc-service lightdm status
ps -eo pid,ppid,stat,wchan:24,args | grep -E 'lightdm|Xorg|greeter|onboard'
DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 xset q
DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 xrandr --verbose
for f in /sys/class/backlight/*/brightness /sys/class/backlight/*/actual_brightness /sys/class/backlight/*/max_brightness /sys/class/backlight/*/bl_power /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel /sys/class/graphics/fb0/stride; do
    [ ! -f "$f" ] || { echo "$f"; cat "$f"; }
done
tail -25 /var/log/lightdm/lightdm.log
tail -25 /var/log/lightdm/seat0-greeter.log
dmesg | tail -100
printf '\nGTA4L_DISPLAY_STATE_END\n'
stty echo
