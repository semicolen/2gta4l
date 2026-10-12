stty -echo
printf '\nGTA4L_KERNEL_STATE_BEGIN\n'
uname -a
cat /proc/cmdline
cat /proc/uptime
printf '\nGTA4L_KERNEL_STATE_END\n'
stty echo
