#!/bin/sh
set -u
echo '=== IPA device and attributes ==='
ls -l /dev/ipa /dev/subsys_ipa_fws
ls -l /sys/bus/platform/drivers/ipa
ls /sys/devices/platform/soc/5800000.qcom,ipa
echo '=== IPA kernel messages ==='
dmesg | grep -Ei 'ipa|rmnet' | tail -n 160
echo '=== Network modules ==='
lsmod | grep -E 'ipa|rmnet'
ls /sys/module/rmnet* /sys/module/ipa* 2>/dev/null
echo IPA_STATE_END
