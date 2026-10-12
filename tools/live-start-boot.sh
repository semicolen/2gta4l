stty -echo
printf '\nGTA4L_BOOT_BEGIN\n'
echo 'GTA4L_STAGE: starting OpenRC boot only' > /dev/kmsg
/sbin/openrc boot </dev/null >/var/log/gta4l/staged-boot.log 2>&1 &
echo "OpenRC boot PID: $!"
printf '\nGTA4L_BOOT_END\n'
stty echo
