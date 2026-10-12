#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
47eed54a5c28d51e9c2a5917930c1ac6343b7d2ece9b616025e56e56e3d384df  /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r1.apk
cd36d906f088627e1399d97aa4d45a1ead2912f5c92b9a2b0e9f4d34eb18f087  /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r1.apk
5cf0dff93e60e3fb0d48dcbbc9f588b149c29e91563f3d10048a5a92eb01203c  /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r1.apk
959cf4d2206bdbd444867fe4c405d9060c1d5426c5f0a88b22f44049d13cbe3c  /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r1.apk
7754172d192585a65f32d85a9539499819d30856c364a3d54210a83917ab07e2  /tmp/gta4l-upload/gps-gta4l-1.0-r1.apk
1b0221a8a4efcf374a36b422fd9424bb42b4524c97939da80184140999e60427  /tmp/gta4l-upload/device-samsung-gta4l-1-r18.apk
ffa275c4ad789a95e89645744342d74e14e4fbdd34948f12e78560587e39dc7e  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r18.apk
486244f7ed569ea2325d370d478f87905d86ab356e46ebeb01e9059d40509c09  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r18.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r1.apk /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r1.apk /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r1.apk /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r1.apk /tmp/gta4l-upload/gps-gta4l-1.0-r1.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r18.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r18.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r18.apk
rc-update -q del gta4l-gps-prepare default 2>/dev/null || true
rc-service gta4l-gps-prepare stop || true
apk --no-network --no-interactive --no-scripts del gps-gta4l-openrc
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
echo GPS_REQUEST_PATH_R18_INSTALLED_BOOT_UNCHANGED
