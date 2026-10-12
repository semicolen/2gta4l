#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax geoclue --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/geoclue-build.log"
cp "$ROOT/work/packages/edge/aarch64/geoclue-2.8.2-r0.apk" "$WORKSPACE/artifacts/apks/"
bash "$WORKSPACE/tools/sync-port.sh" build --lax gps-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/gps-gta4l-build.log"
for name in gps-gta4l gps-gta4l-openrc; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1.0-r0.apk" "$WORKSPACE/artifacts/apks/"
done
echo GPS_INTEGRATION_LOCAL_WSL_BUILD_COMPLETE
