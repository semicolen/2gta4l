#!/bin/sh
set -u
iface=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
case "$iface" in wlan0|swlan0) ;; *) echo 'No connected WLAN interface' >&2; exit 1;; esac
echo "=== Wi-Fi interface $iface ==="
nmcli -f GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$iface"
ip -4 route show default
ip -4 route get 1.1.1.1
echo '=== IP connectivity through Wi-Fi ==='
ping -4 -I "$iface" -c 3 -W 3 1.1.1.1
echo "wifi_ip_ping_status=$?"
echo '=== DNS and website ping through Wi-Fi ==='
ping -4 -I "$iface" -c 3 -W 3 postmarketos.org
echo "wifi_dns_ping_status=$?"
echo '=== HTTPS through Wi-Fi ==='
if command -v curl >/dev/null 2>&1; then
    curl --interface "$iface" --ipv4 --connect-timeout 5 --max-time 12 --silent --show-error --head https://postmarketos.org/
    echo "wifi_https_status=$?"
else
    echo 'curl not installed; HTTPS test pending'
fi
echo WIFI_CONNECTIVITY_TEST_END
