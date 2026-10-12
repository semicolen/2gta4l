#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax device-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/device-r16-build.log"
for pkg in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1-r16.apk" "$WORKSPACE/artifacts/apks/"
done
echo DEVICE_R16_LOCAL_WSL_BUILD_COMPLETE
