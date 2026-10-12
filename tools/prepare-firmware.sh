#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
mkdir -p "$ROOT/stock/modem-files"
mdir -i "$ROOT/stock/modem.bin" ::
if [ ! -d "$ROOT/stock/modem-files/image" ]; then
    mcopy -D o -s -i "$ROOT/stock/modem.bin" '::image' "$ROOT/stock/modem-files/"
fi
mkdir -p "$ROOT/stock/apnhlos-files"
if [ ! -d "$ROOT/stock/apnhlos-files/image" ]; then
    mcopy -D o -s -i "$ROOT/stock/NON-HLOS.bin" '::image' "$ROOT/stock/apnhlos-files/"
fi
mkdir -p "$ROOT/firmware-stage/lib/firmware/postmarketos"
cp -a "$ROOT/stock/vendor/root/firmware/." "$ROOT/firmware-stage/lib/firmware/postmarketos/"
cp -a "$ROOT/stock/modem-files/image/." "$ROOT/firmware-stage/lib/firmware/postmarketos/"
cp -a "$ROOT/stock/apnhlos-files/image/." "$ROOT/firmware-stage/lib/firmware/postmarketos/"
# Convert stock absolute Wi-Fi config links to local firmware copies.
find "$ROOT/firmware-stage" -type l -print -delete
mkdir -p "$ROOT/firmware-stage/lib/firmware/postmarketos/wlan/prima" "$ROOT/firmware-stage/vendor/etc/wifi"
cp "$ROOT/stock/vendor/root/wifi/WCNSS_qcom_cfg.ini" "$ROOT/firmware-stage/lib/firmware/postmarketos/wlan/prima/"
cp -a "$ROOT/stock/vendor/root/wifi/." "$ROOT/firmware-stage/vendor/etc/wifi/"
mkdir -p "$ROOT/firmware-stage/vendor/firmware_mnt"
ln -sfnT /lib/firmware/postmarketos "$ROOT/firmware-stage/vendor/firmware_mnt/image"
ln -sfnT /lib/firmware/postmarketos "$ROOT/firmware-stage/vendor/firmware"
mkdir -p "$ROOT/firmware-stage/vendor/firmware-modem" "$ROOT/firmware-stage/vendor/bt_firmware"
ln -sfnT /lib/firmware/postmarketos "$ROOT/firmware-stage/vendor/firmware-modem/image"
ln -sfnT /lib/firmware/postmarketos "$ROOT/firmware-stage/vendor/bt_firmware/image"
mkdir -p "$WORKSPACE/firmware-local"
tar --sort=name --mtime='UTC 2024-07-03' --owner=0 --group=0 --numeric-owner -czf "$WORKSPACE/firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz" -C "$ROOT/firmware-stage" lib vendor
sha512sum "$WORKSPACE/firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz"
python3 "$WORKSPACE/tools/update-firmware-checksum.py"
find "$ROOT/firmware-stage/lib/firmware/postmarketos" -type f | wc -l
cat "$ROOT/stock/vendor/root/modules/modules.load"
rg -n 'WCNSS_qcom|bdwlan|wlanmdsp|firmware|wlan/prima' "$ROOT/kernel/drivers/staging/qcacld-3.0/configs/default" "$ROOT/kernel/drivers/soc/qcom/icnss.c" | head -45 || true
