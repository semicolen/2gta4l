#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
sink=$(pactl list short sinks | awk '/alsa_output/ {print $2; exit}')
[ -n "$sink" ]
pactl set-sink-volume "$sink" 60%
pactl set-sink-mute "$sink" 0
nohup /bin/sh -c '
    status=0
    timeout -k 2 36 paplay /run/gta4l-audio/quiet-tone.wav || status=$?
    echo "DESKTOP_PLAYBACK_STATUS=$status"
    pacmd set-log-level 2
    pacmd set-log-target syslog
    exit "$status"
' </dev/null > /home/tablet/.cache/gta4l-desktop-speaker-test.log 2>&1 &
echo "DESKTOP_SPEAKER_TEST_PID=$!"
sleep 1
pactl list short sinks
cat /home/tablet/.cache/gta4l-desktop-speaker-test.log
