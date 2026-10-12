#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/prepare-sensor-firmware-package.py"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
for pkg in firmware-sensors-gta4l sensors-gta4l rotation-gta4l; do
    python3 "$WORKSPACE/tools/configure-port.py"
    bash "$WORKSPACE/tools/sync-port.sh" build --lax "$pkg" --arch aarch64 --force
    cp "$ROOT/work/log.txt" "$WORKSPACE/logs/$pkg-local-build.log"
    cp "$ROOT/work/packages/edge/aarch64/""$pkg"-*.apk "$WORKSPACE/artifacts/apks/"
done
echo ROTATION_LOCAL_WSL_BUILD_COMPLETE
