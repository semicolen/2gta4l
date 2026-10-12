#!/bin/sh
set -eu
printf '=== Installed location libraries ===\n'
apk list --installed libmm-glib libnotify avahi-libs avahi-glib json-glib libsoup3 glib musl libintl
printf '=== Active desktop session ===\n'
pidof xfce4-session || true
printf '=== Device identity ===\n'
tr '\000' '\n' < /proc/device-tree/model
printf '\nGPS_GEO_DEPENDENCIES_END\n'
