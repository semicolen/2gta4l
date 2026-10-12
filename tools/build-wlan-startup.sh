#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
bash "$WORKSPACE/tools/sync-port.sh" build --lax wlfw-gta4l device-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/wlan-startup-r13-build.log"
cp "$ROOT/work/packages/edge/aarch64/wlfw-gta4l-1.0-r0.apk" "$WORKSPACE/artifacts/apks/"
for name in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1-r13.apk" "$WORKSPACE/artifacts/apks/"
done
sha256sum "$WORKSPACE/artifacts/apks/wlfw-gta4l-1.0-r0.apk" "$WORKSPACE/artifacts/apks/"*-1-r13.apk
