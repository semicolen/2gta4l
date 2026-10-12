#!/bin/sh
set -eu
echo '=== Bluetooth networking packages ==='
apk info -v | grep -E '^(bluez|networkmanager|blueman|python3|e2fsprogs)' | sort
echo '=== NetworkManager plugins ==='
find /usr/lib/NetworkManager -maxdepth 3 -type f -name '*bluetooth*'
echo '=== Bluetooth daemon configuration ==='
cat /etc/conf.d/bluetooth
grep -E '^[[:space:]]*(AutoEnable|Experimental|KernelExperimental|ControllerMode|DisablePlugins|EnablePlugins)[[:space:]]*=' /etc/bluetooth/main.conf || true
echo '=== Default runlevel ==='
rc-update show default | grep -E 'bluetooth|NetworkManager|lightdm|gta4l'
echo BT_NETWORK_PREREQUISITES_END
