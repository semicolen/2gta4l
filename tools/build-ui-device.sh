#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax device-samsung-gta4l --arch aarch64 --force
for package in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware device-samsung-gta4l-xfce; do
    cp "$ROOT/work/packages/edge/aarch64/$package-1-r23.apk" "$WORKSPACE/artifacts/apks/"
done
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/ui-device-build.log"
echo UI_NEUTRAL_DEVICE_R23_BUILT_LOCALLY
