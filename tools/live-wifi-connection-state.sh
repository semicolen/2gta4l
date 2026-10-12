#!/bin/sh
# Read connection state without printing saved Wi-Fi passwords.
set -u
echo '=== NetworkManager state ==='
nmcli -f DEVICE,TYPE,STATE,CONNECTION device status
nmcli -f GENERAL,IP4,IP6 device show wlan0
nmcli -f NAME,UUID,TYPE,DEVICE connection show
nmcli general logging
echo '=== Radio state and available access points ==='
nmcli radio
nmcli -f IN-USE,SSID,CHAN,FREQ,SIGNAL,SECURITY device wifi list ifname wlan0 --rescan no
echo '=== Supplicant and log facilities ==='
rc-service wpa_supplicant status
command -v logread || true
command -v logbookctl || true
command -v journalctl || true
if command -v wpa_cli >/dev/null 2>&1; then
    wpa_cli -i wlan0 status
fi
echo '=== Recent connection messages ==='
if command -v logread >/dev/null 2>&1; then
    logread | grep -Ei 'NetworkManager|supplicant|wlan0|swlan0|dhcp' | tail -n 180
fi
for log in /var/log/messages /var/log/NetworkManager.log /var/log/wpa_supplicant.log; do
    if [ -f "$log" ]; then
        tail -n 800 "$log" | grep -Ei 'NetworkManager|supplicant|wlan0|swlan0|dhcp' | tail -n 180
    fi
done
echo '=== Recent WLAN kernel messages ==='
dmesg | grep -Ei 'wlan|cnss|icnss|hdd|sme|pe:|wma|cfg80211|auth|assoc|cipher|eapol' | tail -n 180
echo WIFI_CONNECTION_STATE_END
