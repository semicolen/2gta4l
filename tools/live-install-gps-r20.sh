#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
f34ea46c0c4c46a9fc3c831a25cc28f8396001534ee08eaac2b18a4097b062a7  /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r3.apk
84e732b3e2f3e8dc8cbe3a43fdfcf8326ac7b9f4246a01b2a53a274a0fb5d084  /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r3.apk
ed55060287be9171fb171cb20146cd5e7e49921b60d09abd4fc3df259dfca41a  /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r3.apk
b46322b04a00a5c6d49132496f844df8d70fe6ff9a99485a55a43540c11f2b15  /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r3.apk
bfc7c145fbe528fb799474e179b2ff74a3d9b50d0a619fd2b5807249e0a07b24  /tmp/gta4l-upload/gps-gta4l-1.0-r3.apk
2fd85fbd912292336283cd29e001695b98c6703743e54878b6666597e80dcec3  /tmp/gta4l-upload/device-samsung-gta4l-1-r20.apk
6d878cd766b286a385d0f92e39990cadf8f87d36eaa7b8b1b380564bdb2ba331  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r20.apk
d70cc3c5f306f54cc966abc92f355d2fa3f6d22576ce8fd0d99dcb530680dfd5  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r20.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/modemmanager-1.25.95_git20261005-r3.apk /tmp/gta4l-upload/modemmanager-openrc-1.25.95_git20261005-r3.apk /tmp/gta4l-upload/modemmanager-udev-1.25.95_git20261005-r3.apk /tmp/gta4l-upload/libmm-glib-1.25.95_git20261005-r3.apk /tmp/gta4l-upload/gps-gta4l-1.0-r3.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r20.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r20.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r20.apk
rc-update -q del gta4l-gps-prepare default 2>/dev/null || true
if apk info -e gps-gta4l-openrc >/dev/null 2>&1; then
    rc-service gta4l-gps-prepare stop || true
    apk --no-network --no-interactive --no-scripts del gps-gta4l-openrc
fi
service=/usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
mkdir -p /var/log/gta4l/gps-private
chmod 700 /var/log/gta4l/gps-private
cp /etc/conf.d/modemmanager /var/log/gta4l/gps-private/modemmanager.confd.before-r20
printf '%s\n' 'modemmanager_opts="--test-quick-suspend-resume --log-file=/var/log/gta4l/gps-private/modemmanager-direct.log"' > /etc/conf.d/modemmanager
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
echo GPS_REQUEST_PATH_R20_INSTALLED_BOOT_UNCHANGED
