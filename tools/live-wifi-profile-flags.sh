#!/bin/sh
set -u
echo '=== Saved Wi-Fi profile flags (no secrets) ==='
for uuid in $(nmcli -t -f UUID,TYPE connection show | awk -F: '$2 == "802-11-wireless" || $2 == "wifi" {print $1}'); do
    nmcli -f connection.id,connection.uuid,connection.autoconnect,connection.permissions,connection.interface-name,802-11-wireless-security.psk-flags connection show "$uuid"
done
echo '=== Current desktop state ==='
pgrep -a -u tablet -x xfce4-session || true
pgrep -a -u tablet -x nm-applet || true
nmcli -f DEVICE,TYPE,STATE,CONNECTION device
echo WIFI_PROFILE_FLAGS_END
