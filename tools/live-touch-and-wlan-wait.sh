stty -echo
printf '\nGTA4L_TOUCH_WLAN_BEGIN\n'
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
xinput list
for id in $(xinput list --id-only); do echo "INPUT ID $id"; xinput list-props "$id"; done
cat /proc/bus/input/devices
for dev in /dev/input/event*; do udevadm info -q property -n "$dev" | grep -E 'DEVNAME|ID_INPUT|CALIBRATION|NAME'; done
ps -eo pid,ppid,stat,wchan:30,args | grep -E 'wlan|gta4l|ash'
cat /proc/4037/stack
cat /proc/4037/wchan
cat /var/log/gta4l/wlan-start.log
printf '\nGTA4L_TOUCH_WLAN_END\n'
stty echo
