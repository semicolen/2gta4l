#!/usr/bin/env bash
set -eu
ROOT=/home/pmos/sm-t505-port
rg -n 'deviceinfo_dtb|header_version|mkbootimg|dtb_file|dtb=' "$ROOT/sources/boot-deploy" | head -130
cat "$ROOT/kernel/arch/arm64/boot/dts/vendor/qcom/Makefile" | tail -140
cat "$ROOT/kernel/arch/arm64/boot/Makefile" | head -110
cat "$ROOT/kernel/techpack/camera-bengal/config/bengalcamera.conf"
