#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 git sudo openssl ca-certificates ripgrep lz4 file xz-utils bzip2 unzip zip curl qemu-user qemu-user-binfmt binfmt-support kpartx mtools e2fsprogs
mkdir -p "$WORKSPACE/port" "$WORKSPACE/evidence" "$WORKSPACE/firmware-local" "$WORKSPACE/artifacts"
for name in device-samsung-gta4l linux-samsung-gta4l firmware-samsung-gta4l; do
    if [ ! -d "$WORKSPACE/port/$name" ]; then
        cp -a "$ROOT/sources/base-port/$name" "$WORKSPACE/port/"
    fi
done
if [ ! -d "$ROOT/sources/pmaports/.git" ]; then
    git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$ROOT/sources/pmaports"
fi
find "$ROOT/sources/orangefox/device" -maxdepth 5 -type f -printf '%p %s bytes\n'
cat "$ROOT/sources/orangefox/device/samsung/gta4l/BoardConfig.mk"
rg -n 'dependencies|qemu|binfmt|openssl' "$ROOT/sources/pmbootstrap/pmb/helpers/dependencies.py" || true
