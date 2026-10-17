#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/prepare-modem-gps-direct-patch.py"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax modemmanager --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/modemmanager-gps-build.log"
for pkg in modemmanager modemmanager-openrc modemmanager-udev libmm-glib; do
    cp "$ROOT/work/packages/edge/aarch64/$pkg-1.25.95_git20261005-r3.apk" "$WORKSPACE/artifacts/apks/"
done
echo MODEMMANAGER_GPS_LOCAL_WSL_BUILD_COMPLETE
