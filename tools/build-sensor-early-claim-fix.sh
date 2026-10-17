#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WS/tools/prepare-sensor-early-claim-fix.py"
python3 "$WS/tools/configure-port.py"
patch --dry-run -p1 -d "$ROOT/diagnostics/sensor-proxy-source/iio-sensor-proxy-3.9" < "$WS/port/iio-sensor-proxy/ssc-early-claim.patch"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/sync-port.sh" build --lax iio-sensor-proxy --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WS/logs/sensor-proxy-early-claim-build.log"
for suffix in '' '-openrc' '-udev'; do
    cp "$ROOT/work/packages/edge/aarch64/iio-sensor-proxy${suffix}-3.9-r4.apk" "$WS/artifacts/apks/"
done
sha256sum "$WS/artifacts/apks/iio-sensor-proxy"*-3.9-r4.apk
echo SENSOR_PROXY_EARLY_CLAIM_BUILT_LOCALLY_IN_WSL
