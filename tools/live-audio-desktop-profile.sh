#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Add desktop ALSA card with UCM ==='
pactl load-module module-alsa-card device_id=0 use_ucm=yes
echo '=== Card and sink ==='
pactl list short cards
pactl list short sinks
pactl list cards
sink=$(pactl list short sinks | awk '/alsa_output/ {print $2; exit}')
[ -n "$sink" ]
pactl set-default-sink "$sink"
pactl set-sink-volume "$sink" 35%
pactl set-sink-mute "$sink" 0
echo DESKTOP_SPEAKER_PROFILE_READY
