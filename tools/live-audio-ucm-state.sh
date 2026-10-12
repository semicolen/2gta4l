#!/bin/sh
set -eu
echo '=== Completed tone test ==='
cat /run/gta4l-audio/tone-test.log
echo '=== ALSA configuration packages ==='
apk info | grep -E 'alsa|pulse|pipewire|ucm'
command -v alsaucm || true
echo '=== UCM tree ==='
ls -ld /usr/share/alsa/ucm2 /usr/share/alsa/ucm2/conf.d
cat /usr/share/alsa/ucm2/ucm.conf
echo '=== Card identifiers ==='
cat /proc/asound/card0/id
alsaucm -c hw:0 list _verbs || true
echo AUDIO_UCM_STATE_END
