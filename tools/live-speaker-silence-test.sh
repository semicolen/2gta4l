#!/bin/sh
set -eu
mkdir -p /run/gta4l-audio
python3 - <<'PY'
import wave
with wave.open('/run/gta4l-audio/silence.wav', 'wb') as wav:
    wav.setparams((2, 2, 48000, 0, 'NONE', 'not compressed'))
    wav.writeframes(b'\0' * (48000 * 2 * 2 * 3))
PY
amixer -q -c 0 cset "name=Playback 0 Volume" 0
amixer -q -c 0 cset "name=PRIM_MI2S_RX SampleRate" KHZ_48
amixer -q -c 0 cset "name=PRIM_MI2S_RX Format" S16_LE
amixer -q -c 0 cset "name=PRIM_MI2S_RX Channels" Two
amixer -q -c 0 cset "name=PRI_MI2S_RX Audio Mixer MultiMedia1" on,on
status=0
timeout -k 2 10 aplay -v -D hw:0,0 /run/gta4l-audio/silence.wav || status=$?
amixer -q -c 0 cset "name=PRI_MI2S_RX Audio Mixer MultiMedia1" off,off
echo "SILENCE_PLAYBACK_STATUS=$status"
dmesg | grep -Ei 'fsm|fs1801|audio|afe|adm|q6asm' | tail -n 100
echo SPEAKER_SILENCE_TEST_END
exit "$status"
