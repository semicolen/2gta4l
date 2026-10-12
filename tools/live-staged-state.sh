stty -echo
printf '\nGTA4L_STAGED_STATE_BEGIN\n'
cat /proc/uptime
readlink /proc/1/exe
cat /proc/1/cmdline; printf '\n'
cat /proc/mounts
ip addr show usb0
ps
printf '\nGTA4L_STAGED_STATE_END\n'
stty echo
