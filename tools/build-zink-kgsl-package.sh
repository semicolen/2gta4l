#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/configure-port.py"
bash "$WS/tools/pmb.sh" shutdown
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax mesa-zink-kgsl-gta4l --arch aarch64 --force
version=$(sed -n 's/^pkgver=//p' "$WS/port/mesa-zink-kgsl-gta4l/APKBUILD")
revision=$(sed -n 's/^pkgrel=//p' "$WS/port/mesa-zink-kgsl-gta4l/APKBUILD")
cp "$ROOT/work/log.txt" "$WS/logs/zink-kgsl-package-r${revision}-build.log"
cp "$ROOT/work/packages/edge/aarch64/mesa-zink-kgsl-gta4l-$version-r$revision.apk" "$WS/artifacts/apks/"
sha256sum "$WS/artifacts/apks/mesa-zink-kgsl-gta4l-$version-r$revision.apk"
printf 'ZINK_KGSL_PACKAGE_BUILT_LOCALLY_IN_WSL\n'
