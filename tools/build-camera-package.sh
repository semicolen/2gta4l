#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WS='/mnt/c/postmarketOS-gta4l'
revision=$(sed -n 's/^pkgrel=//p' "$WS/port/camera-gta4l/APKBUILD")
python3 "$WS/tools/prepare-camera-package.py"
python3 "$WS/tools/configure-port.py"
bash "$WS/tools/pmb.sh" shutdown
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax camera-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/camera-package-r${revision}-build.log"
for name in camera-gta4l camera-gta4l-openrc; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1.0-r${revision}.apk" "$WS/artifacts/apks/"
done
printf 'CAMERA_PACKAGE_R%s_BUILT_LOCALLY_IN_WSL\n' "$revision"
