#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/generate-sensor-rpc-patch.py"
python3 "$WORKSPACE/tools/verify-sensor-rpc-uapi.py"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax hexagonrpc-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/sensor-rpc-local-build.log"
cp "$ROOT/work/packages/edge/aarch64/"hexagonrpc-gta4l-*.apk "$WORKSPACE/artifacts/apks/"
echo SENSOR_RPC_LOCAL_WSL_BUILD_COMPLETE
