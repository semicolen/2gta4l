#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/prepare-gnome-kernel-fixes.py"
python3 "$WS/tools/configure-port.py"
patch --dry-run -p1 -d "$ROOT/kernel" < "$WS/port/linux-samsung-gta4l/himax-gesture-keycodes.patch"
patch --dry-run -p1 -d "$ROOT/kernel" < "$WS/port/linux-samsung-gta4l/pidfd-waitid.patch"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/sync-port.sh" build --lax linux-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/kernel10-gnome-input-pidfd-build.log"
cp "$ROOT/work/packages/edge/aarch64/linux-samsung-gta4l-4.19.300-r9.apk" "$WS/artifacts/apks/"
sha256sum "$WS/artifacts/apks/linux-samsung-gta4l-4.19.300-r9.apk"
echo KERNEL10_GNOME_FIXES_BUILT_LOCALLY_IN_WSL
