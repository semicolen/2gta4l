stty -echo
printf '\nGTA4L_DISPLAY_LOGS_BEGIN\n'
cat /proc/uptime
rc-service lightdm status
ps -eo pid,ppid,stat,wchan:24,args | grep -E 'lightdm|Xorg|greeter|gta4l|elogind|NetworkManager|ModemManager'
ls -l /var/log/lightdm /var/log/Xorg* /dev/fb* /dev/dri/*
for file in /var/log/lightdm/lightdm.log /var/log/lightdm/x-0.log /var/log/lightdm/seat0-greeter.log /var/log/Xorg.0.log; do
    [ ! -f "$file" ] || { printf '\nLOG:%s\n' "$file"; tail -100 "$file"; }
done
for file in /sys/class/graphics/fb0/name /sys/class/graphics/fb0/modes /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/stride /sys/class/graphics/fb0/blank; do
    [ ! -f "$file" ] || { printf '\nSYS:%s\n' "$file"; cat "$file"; }
done
printf '\nGTA4L_DISPLAY_LOGS_END\n'
stty echo
