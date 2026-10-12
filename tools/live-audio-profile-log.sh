#!/bin/sh
set -u
export XDG_RUNTIME_DIR=/run/user/10000
su tablet -s /bin/sh -c 'pactl set-log-level debug; pactl load-module module-alsa-card device_id=0 use_ucm=yes'
echo '=== PulseAudio diagnostic ==='
tail -n 350 /var/log/messages | grep -Ei 'pulse|alsa|ucm' | tail -n 100
echo '=== Current speaker route ==='
amixer -c 0 cget 'name=PRI_MI2S_RX Audio Mixer MultiMedia1'
echo '=== Kernel PCM diagnostic ==='
dmesg | grep -Ei 'BENGAL Media1|fsm|q6asm|afe_port' | tail -n 45
echo AUDIO_PROFILE_LOG_END
