#!/bin/sh
set -eu
mmcli -G INFO
cp /var/log/gta4l/gps-private/modemmanager.confd.before-r20 /etc/conf.d/modemmanager
printf 'Normal modem startup configuration restored\n'
