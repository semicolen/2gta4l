stty -echo
printf '\nGTA4L_RADIO_LOGS_BEGIN\n'
cat /proc/uptime
cat /var/log/gta4l/wlan-start.log
ls -l /dev/wlan /sys/class/ieee80211
ip -br link
command -v qrtr-lookup
timeout 4 qrtr-lookup
qmicli --help
ModemManager --version
ModemManager --help
ps -eo pid,args | grep -E 'ModemManager|qrtr|gta4l|pd-mapper|tqftp|rmtfs'
tail -100 /var/log/messages
dmesg | tail -140
printf '\nGTA4L_RADIO_LOGS_END\n'
stty echo
