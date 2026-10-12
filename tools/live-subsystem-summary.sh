#!/bin/sh
set -u
uname -a
rc-service gta4l-adsp status
rc-service gta4l-ipa status
rc-service modemmanager status
echo '=== ALSA cards ==='
cat /proc/asound/cards
echo '=== Subsystem states ==='
for state in /sys/bus/msm_subsys/devices/*/state; do
    printf '%s ' "$state"
    cat "$state"
done
echo '=== RMNET interfaces ==='
ip link show rmnet_ipa0
echo '=== Modem enumeration ==='
timeout 8 mmcli -L
echo SUBSYSTEM_SUMMARY_END
