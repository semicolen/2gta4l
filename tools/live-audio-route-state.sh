#!/bin/sh
set -u
echo '=== Audio cards and PCM devices ==='
cat /proc/asound/cards /proc/asound/pcm
echo '=== ALSA mixer values ==='
amixer -c 0 contents
echo '=== Audio services ==='
ps -eo pid,uid,args | grep -E 'gta4l-subsystem /dev/subsys_adsp|pulseaudio|pipewire' | grep -v grep
echo '=== Firmware names ==='
find /lib/firmware/postmarketos -type f | grep -Ei 'fsm|acdb|audio' | head -n 60
echo '=== Audio kernel messages ==='
dmesg | grep -Ei 'audio|asoc|fsm|afe|q6asm|adm|adsp' | tail -n 120
echo AUDIO_ROUTE_STATE_END
