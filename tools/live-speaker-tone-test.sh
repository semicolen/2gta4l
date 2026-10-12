#!/bin/sh
set -eu
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
cat > /run/gta4l-audio/tone-test.sh <<'SH'
#!/bin/sh
set -eu
restore() {
    amixer -q -c 0 cset 'name=Playback 0 Volume' 0
    amixer -q -c 0 cset 'name=PRI_MI2S_RX Audio Mixer MultiMedia1' off,off
}
trap restore EXIT HUP INT TERM
amixer -q -c 0 cset 'name=Playback 0 Volume' 4096
amixer -q -c 0 cset 'name=PRI_MI2S_RX Audio Mixer MultiMedia1' on,on
echo TONE_STARTED
timeout -k 2 36 aplay -D hw:0,0 /run/gta4l-audio/quiet-tone.wav
echo TONE_COMPLETED
SH
chmod 700 /run/gta4l-audio/tone-test.sh
nohup /bin/sh /run/gta4l-audio/tone-test.sh </dev/null >/run/gta4l-audio/tone-test.log 2>&1 &
echo "TONE_TEST_PID=$!"
sleep 1
cat /run/gta4l-audio/tone-test.log
