#!/bin/sh
set -eu
python3 /tmp/gta4l-upload/bt-uart-version-probe.py
echo '=== Radio state after version probe ==='
rfkill list
ip -4 route show default
echo BT_UART_VERSION_PROBE_END
