#!/bin/sh
set -u
echo '=== Modem normal-startup detection ==='
ip -br link | grep -E 'rmnet|usb0'
mmcli -L
echo '=== ADSP activation ==='
if ! ps -eo args | grep -q '^/usr/bin/gta4l-subsystem /dev/subsys_adsp$'; then
    mkdir -p /run/gta4l-diagnostic
    nohup /usr/bin/gta4l-subsystem /dev/subsys_adsp </dev/null >/var/log/gta4l/adsp-start.log 2>&1 &
    echo "$!" > /run/gta4l-diagnostic/adsp.pid
    sleep 3
fi
cat /var/log/gta4l/adsp-start.log
cat /proc/asound/cards
echo '=== Mixer controls ==='
amixer -c 0 controls
echo '=== Audio kernel log ==='
dmesg | grep -Ei 'adsp|asoc|codec|wsa|bengal.*snd|sound' | tail -n 60
echo AUDIO_MODEM_STATE_END
