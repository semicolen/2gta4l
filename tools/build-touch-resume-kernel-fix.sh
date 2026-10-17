#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/generate-touch-resume-patch.py"
python3 "$WORKSPACE/tools/configure-port.py"
patch --dry-run -p1 -d "$ROOT/kernel" < "$WORKSPACE/port/linux-samsung-gta4l/touch-resume-order.patch"
bash "$WORKSPACE/tools/sync-port.sh" build --lax linux-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/kernel-touch-resume-fix-build.log"
cp "$ROOT/work/packages/edge/aarch64/linux-samsung-gta4l-4.19.300-r6.apk" "$WORKSPACE/artifacts/apks/"
echo 'Built synchronous TDDI resume kernel locally in WSL Ubuntu'
