#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
cd "$ROOT/kernel"
ls -la techpack
rg -n 'techpack|CONFIG_DRM_MSM|KBUILD_EXTMOD|external|qcacld|audio-kernel|display-drivers' AndroidKernel.mk Android.mk Kbuild Makefile arch/arm64/configs/gta4l_eur_open_defconfig drivers/gpu/drm/msm/Kconfig || true
cat arch/arm64/configs/gta4l_eur_open_defconfig
if [ ! -d "$ROOT/sources/lineage-device" ]; then
    git clone --depth 1 https://github.com/LineageOS/android_device_samsung_sm6115-common.git "$ROOT/sources/lineage-device"
fi
cat "$ROOT/sources/lineage-device/lineage.dependencies"
rg -n 'KERNEL|MODULE|display|wifi' "$ROOT/sources/lineage-device/BoardConfigCommon.mk" "$ROOT/sources/lineage-device/board" || true
if [ ! -d "$ROOT/sources/boot-deploy" ]; then
    git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/boot-deploy.git "$ROOT/sources/boot-deploy"
fi
rg -n 'deviceinfo_dtb|header_version|mkbootimg' "$ROOT/sources/boot-deploy"
