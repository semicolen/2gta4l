#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
5e08f8a25aed83974c5cbe3dfdbc385ea2cd69b4341427604629fc7b70d1f59c  /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r2.apk
cbd48e18bf93d81b15c654d52adc050924b3d8d4f393fa4ff97773fb361b0d7f  /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r2.apk
58db0662ddbedd2e98ff5897f6d3f65c4d677faa8c2177261628db963bea2dbc  /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r2.apk
caca677ff9fe7ff27444eb574c0a306eaa1d8842bbe201a84dccd0aaefbf54f5  /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r2.apk
9b55375c8a692685d80f85fbfb0057fa20fa283b899dbc6ee1833c44a10eeb74  /tmp/gta4l-upload/gps-gta4l-1.0-r2.apk
1554658741c930259ad166fa26e9512bbc4f6d42452511a8121bc393557c30fe  /tmp/gta4l-upload/device-samsung-gta4l-1-r19.apk
e94b157161673cbe86a579d6e7f162799ddc4ff11ed8f2bcf9960c5400880635  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r19.apk
f54f5f3aa39bb2063f59c84362c11320c4583da81434fa8890158f186b5044d6  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r19.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r2.apk /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r2.apk /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r2.apk /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r2.apk /tmp/gta4l-upload/gps-gta4l-1.0-r2.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r19.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r19.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r19.apk
rc-update -q del gta4l-gps-prepare default 2>/dev/null || true
if apk info -e gps-gta4l-openrc >/dev/null 2>&1; then
    rc-service gta4l-gps-prepare stop || true
    apk --no-network --no-interactive --no-scripts del gps-gta4l-openrc
fi
service=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
override=/tmp/gta4l-mm-gps-activation.service
cat > "$override" <<'ACTIVATION'
[D-BUS Service]
Name=org.freedesktop.ModemManager1
Exec=/bin/false
User=root
ACTIVATION
restore_activation() {
    umount "$service"
    dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
}
mount --bind "$override" "$service"
trap restore_activation EXIT
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
rc-service modemmanager stop
rc-service modemmanager start
restore_activation
trap - EXIT
sleep 4
rc-service modemmanager status
mmcli -L
test -f /etc/ModemManager/gta4l-gps-unlock
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo GPS_REQUEST_PATH_R19_INSTALLED_BOOT_UNCHANGED
