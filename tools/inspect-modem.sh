#!/usr/bin/env bash
set -eu
ROOT=/home/pmos/sm-t505-port
rg -n 'firmware-name|rmtfs|adsp|modem' "$ROOT/kernel/arch/arm64/boot/dts/vendor/qcom" -g '*bengal*.dtsi' | head -75 || true
find "$ROOT/sources/pmaports/main" -maxdepth 1 -type d -name '*rmt*' -o -name '*qrtr*' -o -name '*pd-mapper*'
cat "$ROOT/sources/pmaports/device/community/soc-qcom/APKBUILD" | head -110
rg -n 'cmdline|qrtr|rmtfs' "$ROOT/sources/pmaports/main/qrtr" "$ROOT/sources/pmaports/main/rmtfs" "$ROOT/sources/pmaports/main/pd-mapper" || true
tail -25 "$ROOT/work/log.txt"
