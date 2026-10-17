#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/configure-port.py"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax camera-pipewire-gta4l gps-assistance-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/standard-camera-gps-packages-build.log"
for pkg in camera-pipewire-gta4l gps-assistance-gta4l gps-assistance-gta4l-openrc; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1.0-r0.apk" "$WS/artifacts/apks/"
done
echo STANDARD_CAMERA_AND_GPS_ASSISTANCE_PACKAGES_BUILT_LOCALLY_IN_WSL
