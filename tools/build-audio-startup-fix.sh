#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" checksum alsa-ucm-gta4l
cp "$ROOT/sources/pmaports/device/downstream/alsa-ucm-gta4l/APKBUILD" "$WORKSPACE/port/alsa-ucm-gta4l/APKBUILD"
bash "$WORKSPACE/tools/sync-port.sh" build --lax alsa-ucm-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/audio-startup-fix-build.log"
for package in alsa-ucm-gta4l alsa-ucm-gta4l-pulseaudio; do
    cp "$ROOT/work/packages/edge/aarch64/$package-1.0-r3.apk" "$WORKSPACE/artifacts/apks/"
done
echo AUDIO_STARTUP_FIX_LOCAL_WSL_BUILD_COMPLETE
