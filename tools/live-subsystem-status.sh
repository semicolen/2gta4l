#!/bin/sh
set -u
echo '=== Subsystem state ==='
for directory in /sys/bus/msm_subsys/devices/*; do
    [ -d "$directory" ] || continue
    for file in name state firmware_name crash_count; do
        printf '%s: ' "$directory/$file"
        cat "$directory/$file"
    done
done
echo '=== DSP firmware availability ==='
ls -l /lib/firmware/postmarketos/adsp.mdt /lib/firmware/postmarketos/cdsp.mdt /lib/firmware/postmarketos/*wlan*.mdt 2>/dev/null
echo '=== Sound card status ==='
cat /proc/asound/cards
dmesg | grep -Ei 'asoc|snd|codec|machine|wsa|wcd|adsp|cdsp' | tail -n 80
echo SUBSYSTEM_STATUS_END
