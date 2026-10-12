#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Automatically detected desktop audio ==='
su tablet -s /bin/sh -c 'pactl list short cards; pactl list short sinks; pactl info' | head -n 30
count=$(su tablet -s /bin/sh -c 'pactl list short cards' | grep -c 'alsa_card.platform-')
[ "$count" = 1 ]
total=$(su tablet -s /bin/sh -c 'pactl list short cards' | wc -l)
[ "$total" = 1 ]
echo SINGLE_AUTOMATIC_AUDIO_CARD_VERIFIED
mkdir -p /run/gta4l-audio
python3 - <<'PY'
import math, struct, wave
rate = 48000
with wave.open('/run/gta4l-audio/quiet-tone.wav', 'wb') as wav:
    wav.setparams((2, 2, rate, 0, 'NONE', 'not compressed'))
    block = bytearray()
    for i in range(rate * 30):
        phase = i % (rate * 3)
        envelope = min(1.0, phase / 2400, max(0, (rate * 2 - phase) / 2400))
        sample = round(4096 * envelope * math.sin(2 * math.pi * 440 * i / rate))
        block.extend(struct.pack('<hh', sample, sample))
    wav.writeframes(block)
PY
su tablet -s /bin/sh -c 'pactl set-sink-volume @DEFAULT_SINK@ 60%; pactl set-sink-mute @DEFAULT_SINK@ 0'
su tablet -s /bin/sh -c "nohup /bin/sh -c 'status=0; timeout -k 2 36 paplay /run/gta4l-audio/quiet-tone.wav || status=\$?; echo AUTOMATIC_DESKTOP_PLAYBACK_STATUS=\$status; exit \$status' </dev/null >/home/tablet/.cache/gta4l-speaker-reboot-test.log 2>&1 &"
sleep 1
su tablet -s /bin/sh -c 'pactl list short sinks'
echo SPEAKER_AFTER_REBOOT_TEST_STARTED
