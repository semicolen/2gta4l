#!/bin/sh
set -eu
echo '=== Service logging configuration ==='
sed -n '1,220p' /etc/init.d/networkmanager
sed -n '1,200p' /etc/init.d/wpa_supplicant
for file in /etc/conf.d/networkmanager /etc/conf.d/wpa_supplicant; do
    if [ -f "$file" ]; then cat "$file"; fi
done
echo '=== Log files ==='
find /var/log -maxdepth 2 -type f -exec ls -l '{}' ';'
echo '=== NetworkManager logging configuration ==='
grep -R -nE 'backend|level|domains|unmanaged|wifi' /etc/NetworkManager/conf.d /etc/NetworkManager/NetworkManager.conf 2>/dev/null || true
nmcli general logging level DEBUG domains WIFI,SUPPLICANT,AGENTS,SETTINGS,DEVICE,CORE,DHCP4,IP4
echo '=== NetworkManager process output ==='
for pid in $(pidof NetworkManager wpa_supplicant); do
    printf 'PID %s: ' "$pid"
    tr '\000' ' ' < "/proc/$pid/cmdline"
    printf '\n'
    ls -l "/proc/$pid/fd/1" "/proc/$pid/fd/2"
done
echo '=== Connection attempts and permission failures ==='
dmesg | grep -Ei 'wlan.*(connect|auth|assoc|fail)|cfg80211.*(connect|fail)' | tail -n 100
if [ -f /var/log/rc.log ]; then
    tail -n 100 /var/log/rc.log
fi
echo WIFI_LOG_SETUP_END
