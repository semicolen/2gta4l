#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
python3 "$WORKSPACE/tools/generate-qca-tty-guard.py"
python3 "$WORKSPACE/tools/configure-port.py"
patch --dry-run -p1 -d "$ROOT/kernel" < "$WORKSPACE/port/linux-samsung-gta4l/guard-qca-tty.patch"
patch --dry-run -p1 -d "$ROOT/kernel" < "$WORKSPACE/port/linux-samsung-gta4l/restore-bt-module-build.patch"
python3 "$WORKSPACE/tools/test-bt-stock-nvm.py"
bash "$WORKSPACE/tools/sync-port.sh" build --lax linux-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/kernel-bluetooth-build.log"
cp "$ROOT/work/packages/edge/aarch64/linux-samsung-gta4l-4.19.300-r8.apk" "$WORKSPACE/artifacts/apks/"
# Reset native/crossdirect mounts before executing ARM64 build helpers.
bash "$WORKSPACE/tools/pmb.sh" shutdown
sh "$WORKSPACE/tools/ensure-wsl-arm64-emulation.sh"
bash "$WORKSPACE/tools/pmb.sh" chroot -b aarch64 -- /bin/true
bash "$WORKSPACE/tools/sync-port.sh" build --lax bluetooth-gta4l device-samsung-gta4l --arch aarch64 --force
cp "$ROOT/work/log.txt" "$WORKSPACE/logs/bluetooth-packages-build.log"
cp "$ROOT/work/packages/edge/aarch64/bluetooth-gta4l-1.0-r0.apk" "$WORKSPACE/artifacts/apks/"
for name in device-samsung-gta4l device-samsung-gta4l-openrc device-samsung-gta4l-nonfree-firmware; do
    cp "$ROOT/work/packages/edge/aarch64/$name-1-r15.apk" "$WORKSPACE/artifacts/apks/"
done
echo BLUETOOTH_AND_KERNEL9_LOCAL_WSL_BUILD_COMPLETE
