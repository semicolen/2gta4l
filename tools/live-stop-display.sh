stty -echo
printf '\nGTA4L_DISPLAY_STOP_BEGIN\n'
rc-service lightdm stop
printf '\nGTA4L_DISPLAY_STOP_END\n'
stty echo
