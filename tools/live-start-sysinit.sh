stty -echo
printf '\nGTA4L_SYSINIT_BEGIN\n'
echo 'GTA4L_STAGE: starting OpenRC sysinit only' > /dev/kmsg
/sbin/openrc sysinit </dev/null >/var/log/gta4l/staged-sysinit.log 2>&1 &
echo "OpenRC sysinit PID: $!"
printf '\nGTA4L_SYSINIT_END\n'
stty echo
