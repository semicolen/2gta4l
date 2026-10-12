#!/usr/bin/env bash
set -eu
ROOT=/home/pmos/sm-t505-port
rg -n 'gta4l|GTA4L' "$ROOT/kernel/arch/arm64/boot/dts/vendor/qcom/Makefile"
rg -n 'filename|WCNSS_qcom|qca_cld|wlan_mac|bdwlan' "$ROOT/kernel/drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_main.c" "$ROOT/kernel/drivers/staging/qcacld-3.0/Kbuild" | head -60 || true
rg -n 'usr/share/mkinitfs/files' "$ROOT/sources/pmaports/device/downstream" | head -30 || true
find "$ROOT/firmware-stage/lib/firmware/postmarketos" -type f -printf '%P\n'
tail -35 "$ROOT/work/log.txt"
