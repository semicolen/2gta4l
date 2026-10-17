#!/usr/bin/env bash
set -eu
ROOT=/home/ark/sm-t505-port
find "$ROOT/sources/pmaports" -iname '*rmt*' -o -iname '*qrtr*' -o -iname '*qcom*' -o -iname '*pd-mapper*'
rg -n 'firmware-name|adsp|modem|rmtfs' "$ROOT/kernel/arch/arm64/boot/dts/vendor/qcom/bengal*.dtsi" | head -70 || true
sed -n '90,180p' "$ROOT/kernel/arch/arm64/boot/dts/vendor/qcom/Makefile"
find "$ROOT/stock/vendor/root/firmware" -type l -ls
rg -n 'ID_MM_QCOM_SOC|qrtr|rmtfs' "$ROOT/sources/pmaports/device" | head -50 || true
