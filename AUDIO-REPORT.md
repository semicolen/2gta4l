# SM-T505 downstream audio

## Internal microphone — 17 October 2026

`alsa-ucm-gta4l` 1.0-r4 adds the physical internal microphone to the desktop
PulseAudio card. The matching stock QRD `amic1` route uses SoundWire microphone
channel 0, ADC1 at its stock value 10, decimator 2, and TX_CDC_DMA_TX_3 into
MultiMedia1. Capture uses mono S16_LE at 48 kHz and unity digital capture gain.
The shared frontend needs its complete codec route enabled during UCM probing;
connecting only the backend caused DSP `ADSP_EBADPARAM` and rejected the card.
Speaker routing, amplifier protection and interrupt scheduling remain intact.

The installed signed packages match the local sources, and the update preserved
the boot image and every other installed package. Both direct ALSA and desktop
capture recorded four quiet acoustic test pulses above background noise.
An eight-second video saved by GNOME Camera contains one video stream and one
audio stream; decoding its audio reproduces those pulses. The user then recorded
speech and confirmed that voice is audible and clear on playback. The source
suspends after recording. A normal reboot preserves the physical default input,
and the user confirms recording and clear voice playback again after logging in.

The earlier speaker-only r3 configuration exposed a speaker monitor but no physical
recording source, which explains silent camera videos. Headset and call-microphone
routing remain unverified.

The tablet plays speaker audio through ALSA and Xfce's PulseAudio server.
Audio release 1.0-r3 also fixes the reproduced rough playback startup. The
user confirms smooth startup with test tones and incoming Bluetooth audio.
The internal microphone is verified above. Headset/call routing, extended audio
quality and system suspend remain unverified.

## Startup timing repair — 12 October 2026

The user reported rough, jittery sound that improved during playback. This
also reproduced with a generated, uncompressed 48 kHz stereo S16_LE sine wave,
so a compressed audio decoder was not required to reproduce the fault.
The eight-second tone did not finish within the 16-second diagnostic limit.
PulseAudio logged repeated ALSA `Underrun!` messages and progressively
increased its minimum latency and wakeup watermark.

The downstream `msm-pcm-q6-v2.c` driver increments its PCM position when the
DSP completes a block; its pointer callback returns that block position.
The automatically detected speaker used timer scheduling with a two-second
buffer and 500 ms periods. That position reporting does not support the
fine-grained timing needed for short requested client latencies. PulseAudio's
[module documentation](https://wiki.freedesktop.org/www/Software/PulseAudio/Documentation/User/Modules/)
describes interrupt scheduling for hardware with inaccurate timing reports.
The official PulseAudio 17.0 source was inspected locally in WSL.

A temporary comparison used interrupt scheduling and four 10 ms PCM periods.
Both eight-second tones finished in 8.109 / 8.087 seconds, without ALSA
underruns or latency increases. The user confirmed smooth sound from the start.

`alsa-ucm-gta4l-pulseaudio` 1.0-r3 packages this policy. A udev rule excludes
only the internal `bengalqrdsndcar` card from automatic PulseAudio discovery;
a startup fragment loads that card with its existing card/sink names, UCM,
`tsched=no`, four periods and 1920 bytes per period. External ALSA cards and
Bluetooth retain normal discovery. Idle suspension stays enabled. The new
subpackage installs automatically when the UCM package and PulseAudio coexist.

After a fresh PulseAudio start, exactly one real speaker card/sink was loaded
from that startup fragment. Separate eight-second 48 kHz and 44.1 kHz client
tests started from a closed PCM and finished in 8.122 / 8.119 seconds. No ALSA
underruns or minimum-latency increases occurred. The log contained one ALSA
wakeup/availability diagnostic; this check does not claim every debug message
was absent. PCM closed again after the idle timeout. The user then reconnected
the Bluetooth sender and confirmed received audio was audible and smooth from
the start. Route metadata was checked without recording the incoming audio.

The initial r2 startup candidate failed after server restart because
`namereg_fail=true` rejected the names generated from the UCM profile.
That attempt exposed Dummy Output. Release r3 retains automatic name
normalization with `namereg_fail=false`; the failed candidate is superseded.

Both packages were built locally in WSL Ubuntu and installed with package
scripts disabled. The kernel #9 boot image and matching FS1801 firmware hash
were verified unchanged. UCM routes, amplifier gain and calibration were not
modified. Normal device reboot with this new policy, hours-long streaming,
Bluetooth transmission/headsets and system suspend remain unverified.
Evidence and package hashes are in `artifacts/audio-startup-verification.json`;
the bounded raw logs have `device-r21-audio-` prefixes in the diagnostic folder.

## Driver and stock configuration

The signed ADSP firmware starts automatically under `gta4l-adsp`, and
the retained downstream modules expose `bengal-qrd-snd-card`. All four
Fourier FS1801 amplifiers are detected at I2C addresses 0x34–0x37. Their
matching `fs1801.fsm` preset loads successfully, with stock protection
parameters and the devices' existing OTP calibration. Its SHA256 is
`2d9cbee2e1101761aaaf5d55373966618a2b1de8d0c3ccbbc10adfb14763c9d4`.

The matching T505XXS8CXG1 stock `mixer_paths_qrd.xml` selects
`PRI_MI2S_RX Audio Mixer MultiMedia1` for deep-buffer playback. Before
the fix, this route was disabled and `Playback 0 Volume` was zero.
PCM setup repeatedly reported `no backend DAIs enabled`; the desktop
exposed only Dummy Output.

## Packaged repair

`alsa-ucm-gta4l` supplies a HiFi speaker use case and the alias matching
the kernel's card driver and long name. It selects primary MI2S, 48 kHz,
stereo, S16_LE and the matching PCM frontend. The backend must be enabled
in the verb's startup sequence before PulseAudio probes the PCM; placing
it only in the speaker's enable sequence reproduces the probe failure.

The profile retains the stock amplifier scene, gain, firmware and
protection configuration. The DSP playback gain is set to unity, and
desktop volume uses software control rather than exporting the vendor's
inaccurate dB metadata. ALSA's documented
[Use Case Manager format](https://www.alsa-project.org/alsa-doc/alsa-lib/group__ucm__conf.html)
defines the profile and routing sequences.

The configuration and device release 14 were built locally in WSL Ubuntu.
The existing kernel #8 boot image was verified unchanged before and after
each package update. Device release 14 depends on the new UCM package.
The current local clean-install candidate includes this route and the later
startup timing policy; see `CURRENT-BUILD.md` for its validation boundary.

## Observed tests

- A three-second silent ALSA playback completed at 48 kHz, stereo, S16_LE.
  The kernel started and stopped the primary backend and amplifiers.
- A quiet, intermittent 30-second ALSA tone completed; the user heard it.
- The corrected UCM profile exposed a HiFi speaker sink to PulseAudio.
- A 30-second `paplay` test completed with status zero; the user confirmed
  audible, clear beeps from the desktop audio path.
- One normal reboot after installing release 14 reached SSH and started
  ADSP/ALSA and the existing wireless services. After login, PulseAudio
  automatically exposed exactly one speaker card and sink. A further
  30-second desktop playback completed successfully; the user confirmed
  clear sound and working volume keys.

The staged test briefly had both a manually loaded card and a subsequently
detected card in PulseAudio. Debug output contained underrun diagnostics,
so successful short playback does not establish sustained streaming or
timing accuracy. The normal-boot test used a single automatically detected
card without the temporary manual module.

Private raw evidence is saved in `evidence/diagnostic-boot-20261009/`:

- `device-r13-audio-route-state.raw` and `device-r13-audio-pulse-state.raw`
- `device-r13-speaker-silence-test.raw`
- `device-r13-speaker-tone-start.raw` and `device-r13-audio-ucm-state.raw`
- `device-r13-audio-ucm-r1-install.raw`
- `device-r13-audio-desktop-profile-r1.raw`
- `device-r13-desktop-speaker-result.raw`
- `device-r14-audio-package-install.raw`
- `device-r14-audio-normal-boot-state.raw`
- `device-r14-speaker-after-reboot-start.raw`
- `device-r14-speaker-after-reboot-result.raw`

Build hashes and bounded validation flags are recorded in
`artifacts/audio-ucm-verification.json`; APK hashes are in
`artifacts/SHA256SUMS`.
