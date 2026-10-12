stty -echo
printf '\nGTA4L_MODEM_PROBE_BEGIN\n'
cat > /tmp/gta4l-modem-probe.sh <<'GTA4L_PROBE_END'
#!/bin/sh
set -u
for action in --dms-get-manufacturer --dms-get-model --dms-get-operating-mode --nas-get-serving-system --uim-get-card-status; do
    echo "QUERY $action"
    timeout 12 qmicli -d qrtr://0 "$action"
    echo "Query exit: $?"
done
GTA4L_PROBE_END
nohup sh /tmp/gta4l-modem-probe.sh </dev/null >/var/log/gta4l/modem-probes.log 2>&1 &
echo "Modem probe PID: $!"
ps -eo pid,ppid,stat,wchan:30,args | grep -E 'wlan|/bin/sh| sh |gta4l'
printf '\nGTA4L_MODEM_PROBE_END\n'
stty echo
