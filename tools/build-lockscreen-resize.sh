#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
python3 "$WORKSPACE/tools/prepare-lockscreen-resize-patch.py"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
cp "$ROOT/downloads/xfce4-screensaver-4.20.2.tar.xz" "$ROOT/work/cache_distfiles/"
bash "$WORKSPACE/tools/sync-port.sh" build --lax xfce4-screensaver --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/lockscreen-resize-build.log"
cp "$ROOT/work/packages/edge/aarch64/"xfce4-screensaver-4.20.2-r1.apk "$WORKSPACE/artifacts/apks/"
echo LOCKSCREEN_RESIZE_LOCAL_WSL_BUILD_COMPLETE
