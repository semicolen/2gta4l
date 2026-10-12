#!/bin/sh
set -u
echo '=== Connection retry state ==='
nmcli -f DEVICE,TYPE,STATE,CONNECTION device
nmcli -f NAME,TYPE,DEVICE connection show
nmcli -f GENERAL.STATE,GENERAL.REASON,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show wlan0
echo '=== Authorization supervision ==='
for pid in $(pidof polkitd ModemManager || true); do
    ps -p "$pid" -o pid,ppid,uid,comm
    parent=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status")
    ps -p "$parent" -o pid,ppid,uid,comm,args
done
rc-service polkit status
rc-service modemmanager status
tail -n 20 /home/tablet/.local/state/gta4l/xfce-polkit.log
echo '=== Association messages ==='
dmesg | grep -Ei 'wlan.*(connect|auth|assoc|disconnect)|cfg80211.*(connect|auth|assoc)' | tail -n 60
echo WIFI_RETRY_SUMMARY_END
