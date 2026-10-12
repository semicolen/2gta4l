#!/bin/sh
set -eu
echo '=== Active PAN profile ==='
nmcli -f GENERAL,IP4 connection show gta4l-lenovo-pan
echo '=== Connected Bluetooth devices ==='
bluetoothctl devices Connected
echo '=== Desktop speaker card ==='
export XDG_RUNTIME_DIR=/run/user/10000
su tablet -s /bin/sh -c 'pactl list short cards; pactl list short sinks'
echo '=== Kernel warning context ==='
dmesg | grep -E -A 55 -B 3 'WARNING: CPU|BUG:|Oops:|Kernel panic' | tail -n 160 || true
echo '=== Bluetooth service remains supervised ==='
rc-service gta4l-bluetooth status
rc-service bluetooth status
echo BT_POST_TEST_STATE_END
