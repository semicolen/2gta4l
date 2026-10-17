#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/configure-port.py"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WS/tools/sync-port.sh" build --lax snapshot --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/snapshot-shutter-r1-build.log"
for package in snapshot snapshot-lang; do
    cp "$ROOT/work/packages/edge/aarch64/$package-51.0-r1.apk" "$WS/artifacts/apks/"
done
echo SNAPSHOT_SHUTTER_R1_BUILT_LOCALLY_IN_WSL
