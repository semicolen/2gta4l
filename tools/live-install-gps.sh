#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
6ea2e0e1627e7de4f2c46566af97affa132d4bd95f60659f51d8f58c4420e729  /tmp/gta4l-upload/geoclue-2.8.2-r0.apk
1c14bd62cd93bfcaddce4bfa6b605385e1922065b32a5f07eb700660dd1bba4e  /tmp/gta4l-upload/gps-gta4l-1.0-r0.apk
eeb0b2fc0fc7fc49f3b1615308f476857d8dccd2910f03b6fa686db9b04dcc32  /tmp/gta4l-upload/gps-gta4l-openrc-1.0-r0.apk
68fc4b723bdb2948d2d954017b25c6d5a99bf42f38e485aa312103cfacb80613  /tmp/gta4l-upload/avahi-glib-0.9_rc5-r0.apk
a3fa6ccc70a958e7aadb8773616e1851268534d6460e7e8191bbdd8cd6586e5e  /tmp/gta4l-upload/device-samsung-gta4l-1-r17.apk
64cc933cb94e4dec848521202262e394f94f9c602e39e0e2625f69349a3d8017  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r17.apk
963c2b189a350cc0052402a7baf644372e7a9af807ac48eeb8fa731968640c1e  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r17.apk
HASHES
getent group geoclue >/dev/null || addgroup -S geoclue
id geoclue >/dev/null 2>&1 || adduser -S -D -h /var/lib/geoclue -s /sbin/nologin -G geoclue geoclue
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/geoclue-2.8.2-r0.apk /tmp/gta4l-upload/gps-gta4l-1.0-r0.apk /tmp/gta4l-upload/gps-gta4l-openrc-1.0-r0.apk /tmp/gta4l-upload/avahi-glib-0.9_rc5-r0.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r17.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r17.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r17.apk
install -d -m 700 -o geoclue -g geoclue /var/lib/geoclue
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig
rc-update -q add gta4l-gps-prepare default
rc-service gta4l-gps-prepare start
mmcli -m 0 --location-disable-gps-raw --location-disable-gps-nmea
mmcli -m 0 --location-status
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo GPS_INTEGRATION_INSTALLED_BOOT_UNCHANGED
