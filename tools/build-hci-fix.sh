#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/generate-hci-patch.py"
python3 "$WORKSPACE/tools/configure-port.py"
# Verify the patch against the measured source before building.
patch --dry-run -p1 -d "$ROOT/kernel" < "$WORKSPACE/port/linux-samsung-gta4l/restore-hci-sockets.patch"
bash "$WORKSPACE/tools/sync-port.sh" build --lax linux-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/kernel-hci-fix-build.log"
printf 'HCI kernel APK build completed in WSL Ubuntu\n'
