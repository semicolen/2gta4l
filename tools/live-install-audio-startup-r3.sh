#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
c80dce64566b90284a8504985a3dca462c36446bbbbaf01dfa3c44c7cc2cedee  /tmp/gta4l-upload/alsa-ucm-gta4l-1.0-r3.apk
5b36b3b2bf0b8bccc10ec315aa788b5d89afd01dec52e9db8da1e6262ac8ff0f  /tmp/gta4l-upload/alsa-ucm-gta4l-pulseaudio-1.0-r3.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/alsa-ucm-gta4l-1.0-r3.apk /tmp/gta4l-upload/alsa-ucm-gta4l-pulseaudio-1.0-r3.apk
udevadm control --reload-rules
udevadm trigger --subsystem-match=sound --sysname-match=card0 --action=change
udevadm settle --timeout=5
udevadm info --query=property --path=/sys/class/sound/card0 | grep '^PULSE_IGNORE=1$'
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum /lib/firmware/postmarketos/fs1801.fsm
echo AUDIO_STARTUP_R3_INSTALLED_BOOT_UNCHANGED
