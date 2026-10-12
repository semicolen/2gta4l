stty -echo
printf '\nGTA4L_XORG_TRACE_BEGIN\n'
cat /var/log/gta4l/hci-fix-Xorg-modesetting-gdb.log
ps -eo pid,stat,wchan:20,args | grep -E 'gdb|Xorg|lightdm|greeter'
printf '\nGTA4L_XORG_TRACE_END\n'
stty echo
