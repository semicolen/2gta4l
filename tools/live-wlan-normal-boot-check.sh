#!/bin/sh
set -u
echo '=== Normal boot ==='
uname -a
cat /proc/uptime
cat /proc/sys/kernel/random/boot_id
echo '=== Automatic services ==='
for service in gta4l-wlan gta4l-modem gta4l-tqftpserv polkit modemmanager lightdm; do
    rc-service "$service" status
done
echo '=== WLAN initialization log ==='
tail -n 70 /var/log/gta4l/wlan-initialize.log
echo '=== Wi-Fi state ==='
nmcli -f DEVICE,TYPE,STATE,CONNECTION device
ip -4 route show default
echo '=== Authorization daemon supervision ==='
for pid in $(pidof polkitd ModemManager || true); do
    parent=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status")
    ps -p "$pid" -o pid,ppid,uid,comm
    ps -p "$parent" -o pid,ppid,uid,comm,args
done
echo '=== ModemManager launch configuration ==='
cat /etc/init.d/modemmanager
cat /etc/conf.d/modemmanager
echo '=== Current WLAN kernel readiness ==='
dmesg | grep -Ei 'WLAN FW is ready|Kernel panic|BUG:|wlan.*(connect|assoc|auth)|icnss.*error' | tail -n 50
echo WLAN_NORMAL_BOOT_CHECK_END
