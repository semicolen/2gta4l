#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Desktop playback result ==='
cat /home/tablet/.cache/gta4l-desktop-speaker-test.log
echo '=== Desktop output after idle ==='
su tablet -s /bin/sh -c 'pactl list short sinks; pactl info' | head -n 25
echo '=== Backend route and gain ==='
amixer -c 0 cget 'name=PRI_MI2S_RX Audio Mixer MultiMedia1'
amixer -c 0 cget 'name=Playback 0 Volume'
echo '=== PulseAudio probe evidence ==='
grep -Ei 'ucm|format|sample rate|alsa.*sink|backend|fail|error' /home/tablet/.cache/gta4l-pulse-debug.log | tail -n 55
echo SPEAKER_RESULT_END
