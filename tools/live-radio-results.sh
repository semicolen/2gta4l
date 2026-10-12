stty -echo
printf '\nGTA4L_RADIO_RESULTS_BEGIN\n'
cat /proc/uptime
cat /var/log/gta4l/modem-probes.log
tail -100 /var/log/gta4l/modemmanager-debug.log
cat /var/log/gta4l/modemmanager-launch.log
cat /var/log/gta4l/wlan-start.log
mmcli -L
ip -br link
ps -eo pid,ppid,stat,wchan:30,args | grep -E 'wlan|ModemManager|qmicli|/bin/sh| sh '
printf '\nGTA4L_RADIO_RESULTS_END\n'
stty echo
