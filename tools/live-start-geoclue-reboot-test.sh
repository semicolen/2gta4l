#!/bin/sh
set -eu
# This native test uses GeoClue's system bus API and needs no graphical login.
# It runs as the same unprivileged tablet user; the normal provider handles GPS.
su tablet -s /bin/sh -c '
umask 077
mkdir -p "$HOME/.cache/gta4l-gps"
chmod 700 "$HOME/.cache/gta4l-gps"
nohup /usr/libexec/geoclue-2.0/demos/where-am-i --timeout=180 >"$HOME/.cache/gta4l-gps/where-am-i.log" 2>&1 </dev/null &
echo "Fresh-boot GeoClue test client started as tablet"
'
sleep 2
mmcli -m 0 --location-status
printf 'GEOCLUE_REBOOT_TEST_STARTED\n'
