#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
sha256sum -c - <<'HASHES'
4d8114850146b58efa4a0160d3ccc38f9b6d6b30f032e40552303fa001c2e822  /tmp/gta4l-upload/alsa-ucm-gta4l-1.0-r1.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/alsa-ucm-gta4l-1.0-r1.apk
alsaucm -c hw:0 list _verbs
alsaucm -c hw:0 set _verb HiFi list _devices set _enadev Speaker get PlaybackPCM/Speaker
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
echo AUDIO_UCM_INSTALLED_BOOT_UNCHANGED
