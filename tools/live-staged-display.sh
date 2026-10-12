stty -echo
printf '\nGTA4L_DISPLAY_BEGIN\n'
echo 'GTA4L_STAGE: starting LightDM only' > /dev/kmsg
rc-service lightdm start </dev/null >/var/log/gta4l/staged-display.log 2>&1 &
echo "Display service task: $!"
printf '\nGTA4L_DISPLAY_END\n'
stty echo
