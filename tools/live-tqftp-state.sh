#!/bin/sh
set -u
echo '=== Firmware server and remoteproc layout ==='
apk info -v tqftpserv
cat /etc/init.d/tqftpserv
cat /etc/conf.d/tqftpserv 2>/dev/null || true
cat /sys/module/firmware_class/parameters/path
ls -ld /sys/class/remoteproc /lib/firmware/postmarketos/wlanmdsp.mbn
ps -eo pid,ppid,comm,args | grep -E '[t]qftpserv|[g]ta4l-modem'
echo '=== Persisted firmware messages ==='
grep -Ei 'tqftp|readonly|wlanmdsp|remoteproc|Invalid.*size' /var/log/rc.log /var/log/messages 2>/dev/null | tail -n 80
echo TQFTP_STATE_END
