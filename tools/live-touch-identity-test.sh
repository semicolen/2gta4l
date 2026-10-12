stty -echo
printf '\nGTA4L_TOUCH_IDENTITY_BEGIN\n'
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
# This changes only the running X server; packaged calibration is preserved.
/tmp/xinput set-prop 8 'libinput Calibration Matrix' 1 0 0 0 1 0 0 0 1
/tmp/xinput list-props 8
printf '\nGTA4L_TOUCH_IDENTITY_END\n'
stty echo
