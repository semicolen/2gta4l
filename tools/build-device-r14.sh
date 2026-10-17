#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax device-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/device-r14-build.log"
for name in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1-r14.apk" "$WORKSPACE/artifacts/apks/"
done
sha256sum "$WORKSPACE/artifacts/apks/"*-1-r14.apk
