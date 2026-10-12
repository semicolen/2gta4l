stty -echo
printf '\nGTA4L_WLAN_SYSFS_BEGIN\n'
find /sys/module/icnss /sys/devices/platform/soc/c800000.qcom,icnss /sys/class/wlan -maxdepth 2 -type f 2>/dev/null
for f in /sys/module/icnss/parameters/* /sys/module/wlan/parameters/*; do [ ! -f "$f" ] || { echo "$f"; cat "$f"; }; done
cat /var/log/gta4l/wlan-start.log
cat /etc/init.d/modemmanager
ps -eo pid,ppid,stat,wchan:30,args | grep -E 'wlan|ModemManager|/bin/sh| sh '
printf '\nGTA4L_WLAN_SYSFS_END\n'
stty echo
