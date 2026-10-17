#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
# Codeberg archives changed compression metadata; all file contents match.
# Use Alpine's original archive with the recipe's published SHA512.
cp "$ROOT/downloads/libssc-0.4.4-alpine.tar.gz" "$ROOT/downloads/libssc-0.4.4.tar.gz"
printf '%s\n' '6b7ec092c645af7210b3fc7c7e3ca48a5d7d74d2b787c103d30de6ca9d64c30479d75e9364d369944dc8b9ac9b4caeb6a9dea4641997aad40ab47fbc41224604  /home/ark/sm-t505-port/downloads/libssc-0.4.4.tar.gz' | sha512sum -c -
cp "$ROOT/downloads/libssc-0.4.4.tar.gz" "$ROOT/work/cache_distfiles/libssc-0.4.4.tar.gz"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax libssc --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/libssc-local-build.log"
cp "$ROOT/work/packages/edge/aarch64/"libssc-*.apk "$WORKSPACE/artifacts/apks/"
python3 "$WORKSPACE/tools/configure-port.py"
bash "$WORKSPACE/tools/sync-port.sh" build --lax iio-sensor-proxy --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/sensor-proxy-local-build.log"
cp "$ROOT/work/packages/edge/aarch64/"iio-sensor-proxy-*.apk "$WORKSPACE/artifacts/apks/"
bash "$WORKSPACE/tools/sync-port.sh" build --lax xinput --arch aarch64 --force
cp "$ROOT/work/packages/edge/aarch64/"xinput-*.apk "$WORKSPACE/artifacts/apks/"
echo SENSOR_LOCAL_WSL_BUILD_COMPLETE
