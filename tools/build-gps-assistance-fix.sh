#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/prepare-gps-assistance-discovery-fix.py"
python3 "$WS/tools/configure-port.py"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
if [ "${1:-}" != --finish-built-modemmanager ]; then
    bash "$WS/tools/sync-port.sh" build --lax modemmanager --arch aarch64 --force
    cp "$ROOT/work/log.txt" "$WS/logs/modemmanager-assistance-r4-build.log"
fi
python3 "$WS/tools/record-gps-assistance-tests.py"
for pkg in modemmanager modemmanager-lang modemmanager-openrc modemmanager-udev libmm-glib; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1.25.95_git20261005-r4.apk" "$WS/artifacts/apks/"
done
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax gps-gta4l --arch aarch64 --force
cp "$ROOT/work/packages/edge/aarch64/gps-gta4l-1.0-r4.apk" "$WS/artifacts/apks/"
echo GPS_ASSISTANCE_FIX_BUILT_AND_TESTED_LOCALLY_IN_WSL
