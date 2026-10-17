#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
# A fixed interpreter works even when the chroot's placeholder is unmounted.
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
# Explicitly initialize this retained build-root after a WSL restart so
# the signing-key, cache and /proc mounts are present before abuild runs.
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax alsa-ucm-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/audio-ucm-build.log"
cp "$ROOT/work/packages/edge/aarch64/alsa-ucm-gta4l-1.0-r1.apk" "$WORKSPACE/artifacts/apks/"
sha256sum "$WORKSPACE/artifacts/apks/alsa-ucm-gta4l-1.0-r1.apk"
