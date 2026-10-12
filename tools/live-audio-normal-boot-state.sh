#!/bin/sh
set -eu
echo '=== Release and boot ==='
uname -a
cat /proc/sys/kernel/random/boot_id /proc/uptime
apk info -v device-samsung-gta4l alsa-ucm-gta4l
echo '=== DSP service and PCM ==='
rc-service gta4l-adsp status
cat /proc/asound/cards
echo '=== Packaged UCM ==='
sha256sum /usr/share/alsa/ucm2/Qualcomm/gta4l/*.conf
readlink /usr/share/alsa/ucm2/conf.d/bengal-qrd-snd-/bengal-qrd-snd-card.conf
echo '=== Speaker firmware ==='
sha256sum /lib/firmware/postmarketos/fs1801.fsm
echo '=== Desktop session processes ==='
ps -eo pid,uid,args | grep -E 'xfce4-session|/usr/bin/pulseaudio' | grep -v grep || true
echo AUDIO_NORMAL_BOOT_STATE_END
