#!/bin/sh
set -eu
printf '=== Boot identity ===\n'
uname -r
cat /proc/sys/kernel/random/boot_id
cat /proc/uptime
printf '=== On-demand GPS configuration ===\n'
apk info -v modemmanager gps-gta4l device-samsung-gta4l
test -f /etc/ModemManager/gta4l-gps-unlock
test ! -L /etc/runlevels/default/gta4l-gps-prepare
rc-service modemmanager status
printf '=== Location state before a client ===\n'
mmcli -L
mmcli -m 0 --location-status
printf '=== Other startup services ===\n'
for service in lightdm gta4l-sensors iio-sensor-proxy gta4l-bluetooth; do
    rc-service "$service" status
done
printf 'GPS_AFTER_REBOOT_END\n'
