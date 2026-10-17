#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/configure-port.py"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax alsa-ucm-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/microphone-ucm-r4-build.log"
for package in alsa-ucm-gta4l alsa-ucm-gta4l-pulseaudio; do
    cp "$ROOT/work/packages/edge/aarch64/$package-1.0-r4.apk" "$WS/artifacts/apks/"
done
echo MICROPHONE_UCM_R4_BUILT_LOCALLY_IN_WSL
