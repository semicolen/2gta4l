#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
AP='/mnt/c/stock-firmware/SM-T505/AP_T505XXS8CXG1_T505XXS8CXG1_MQB82453393_REV00_user_low_ship_MULTI_CERT_meta_RKEY_OS12.tar.md5'
if [ ! -f "$ROOT/stock/super.img" ]; then
    tar -xOf "$AP" super.img.lz4 | lz4 -d - "$ROOT/stock/super.img"
fi
if [ ! -f "$ROOT/stock/vendor/vendor.img" ]; then
    python3 "$ROOT/sources/orangefox/tools/extract_vendor.py" "$ROOT/stock/super.img" "$ROOT/stock/vendor"
fi
mkdir -p "$ROOT/stock/vendor/root"
debugfs -R "rdump /firmware $ROOT/stock/vendor/root" "$ROOT/stock/vendor/vendor.img"
debugfs -R "rdump /etc/wifi $ROOT/stock/vendor/root" "$ROOT/stock/vendor/vendor.img"
debugfs -R "rdump /lib/modules $ROOT/stock/vendor/root" "$ROOT/stock/vendor/vendor.img"
file "$ROOT/stock/modem.bin"
cp "$ROOT/stock/boot/stock-boot.json" "$WORKSPACE/evidence/stock-boot.json"
cp "$ROOT/stock/recovery/stock-boot.json" "$WORKSPACE/evidence/stock-recovery.json"
ls -l "$ROOT/stock/vendor/root"
