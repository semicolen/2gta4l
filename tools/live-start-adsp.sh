#!/bin/sh
set -eu
[ -c /dev/subsys_adsp ]
[ -s /lib/firmware/postmarketos/adsp.mdt ]
echo 'GTA4L_TEST: signed ADSP firmware activation' > /dev/kmsg
nohup /usr/bin/gta4l-subsystem /dev/subsys_adsp \
    </dev/null >/var/log/gta4l/adsp-start.log 2>&1 &
echo "$!" > /run/gta4l-diagnostic/adsp.pid
sleep 3
cat /var/log/gta4l/adsp-start.log
cat /sys/bus/msm_subsys/devices/subsys0/state
qrtr-lookup | grep -E '45 |Remote|registry|Audio|service|Service' | tail -n 35
ls -l /lib/firmware/postmarketos/*wlan* /lib/firmware/postmarketos/*wcnss* 2>/dev/null || true
echo ADSP_START_END
