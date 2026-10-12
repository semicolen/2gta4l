stty -echo
printf '\nGTA4L_RADIO_PLATFORM_BEGIN\n'
for pid in $(pidof ModemManager); do echo "MM PID $pid"; readlink /proc/$pid/exe; done
cat /sys/kernel/debug/devices_deferred
ls -l /sys/bus/platform/drivers/*ipa* /sys/bus/platform/drivers/*icnss* /sys/bus/platform/drivers/*smp2p* 2>/dev/null
find /sys/devices/platform/soc -maxdepth 2 -iname '*ipa*' -o -iname '*smp2p*' -o -iname '*wcnss*'
find /sys/class -maxdepth 2 -iname '*subsys*' -o -iname '*pil*'
ls -l /lib/firmware/postmarketos/*wlan* /lib/firmware/postmarketos/*wcnss* /lib/firmware/postmarketos/*ipa* 2>/dev/null
cat /var/log/gta4l/wlan-start.log
ps -eo pid,ppid,stat,wchan:30,args | grep -E 'wlan|ModemManager|/bin/sh| sh '
printf '\nGTA4L_RADIO_PLATFORM_END\n'
stty echo
