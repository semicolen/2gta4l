#!/bin/sh
set -u
echo '=== Logging reader options ==='
logread --help 2>&1 | head -n 80
echo '=== System bus owners ==='
for name in org.freedesktop.PolicyKit1 org.freedesktop.NetworkManager org.freedesktop.login1; do
    dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:"$name"
done
echo '=== NetworkManager permissions reply ==='
dbus-send --system --print-reply --dest=org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager.GetPermissions
echo '=== Recent logs ==='
logread | tail -n 120
echo '=== Authorization service state ==='
rc-service polkit status
rc-service elogind status
cat /etc/init.d/polkit
ls -l /etc/conf.d/polkit /etc/polkit-1/rules.d
echo '=== Desktop authentication agent messages ==='
tail -n 100 /home/tablet/.xsession-errors 2>/dev/null || true
echo WIFI_AUTHORIZATION_STATE_END
