#!/bin/sh
set -u
echo '=== Desktop user NetworkManager permissions ==='
id
nmcli general permissions
echo '=== Desktop agents ==='
pgrep -a nm-applet || true
pgrep -a polkit || true
echo WIFI_USER_PERMISSIONS_END
