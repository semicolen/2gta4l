#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/extract-modem-gps-tests.py"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
for pkg in gps-gta4l device-samsung-gta4l; do
    bash "$WORKSPACE/tools/sync-port.sh" build --lax "$pkg" --arch aarch64 --force
done
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/gps-device-r19-build.log"
cp "$ROOT/work/packages/edge/aarch64/gps-gta4l-1.0-r2.apk" "$WORKSPACE/artifacts/apks/"
for pkg in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1-r19.apk" "$WORKSPACE/artifacts/apks/"
done
echo GPS_DEVICE_R19_LOCAL_WSL_BUILD_COMPLETE
