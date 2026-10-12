stty -echo
printf '\nGTA4L_DRM_STACKS_BEGIN\n'
cat /proc/uptime
ps -eo pid,ppid,stat,wchan:28,args | grep -E 'Xorg|lightdm|drm|crtc|commit|disp|sde|mdss'
for pid in $(pidof Xorg); do
    echo "Xorg $pid kernel stack"
    cat "/proc/$pid/stack"
done
dmesg | tail -130
printf '\nGTA4L_DRM_STACKS_END\n'
stty echo
