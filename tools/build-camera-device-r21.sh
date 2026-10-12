#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WS='/mnt/c/postmarketOS-gta4l'
bash "$WS/tools/build-camera-package.sh"
bash "$WS/tools/sync-port.sh" build --lax device-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/camera-device-r21-build.log"
for name in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1-r21.apk" "$WS/artifacts/apks/"
done
printf 'CAMERA_DEVICE_R21_BUILT_LOCALLY_IN_WSL\n'
