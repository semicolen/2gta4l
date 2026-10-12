#!/bin/sh
set -u
echo '=== Installed authorization versions ==='
apk --no-network info -v polkit glib elogind networkmanager
echo '=== Process authorization probe ==='
pkcheck --action-id org.freedesktop.NetworkManager.network-control --process "$$"
echo "pkcheck_status=$?"
echo '=== User bus permissions reply ==='
dbus-send --system --print-reply --dest=org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager.GetPermissions
echo POLKIT_PROCESS_PROBE_END
