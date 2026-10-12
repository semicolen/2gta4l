#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
cp "$ROOT/work/chroot_buildroot_aarch64/home/pmos/build/src/ModemManager-7f0bf17ab518cd78925cf7e53cc0d5c42f88b41a/output/meson-logs/testlog.txt" "$WORKSPACE/logs/modemmanager-gps-tests.log"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
for pkg in gps-gta4l device-samsung-gta4l; do
    bash "$WORKSPACE/tools/sync-port.sh" build --lax "$pkg" --arch aarch64 --force
done
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/gps-device-r18-build.log"
cp "$ROOT/work/packages/edge/aarch64/gps-gta4l-1.0-r1.apk" "$WORKSPACE/artifacts/apks/"
for pkg in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1-r18.apk" "$WORKSPACE/artifacts/apks/"
done
echo GPS_DEVICE_R18_LOCAL_WSL_BUILD_COMPLETE
