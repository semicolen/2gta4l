#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
mkdir -p "$ROOT/work/cache_distfiles" "$ROOT/sources/pmaports/device/downstream"
for pkg in "$WORKSPACE"/port/*; do
    cp -a "$pkg" "$ROOT/sources/pmaports/device/downstream/"
done
cp --update=none "$ROOT/downloads/"*.tar.gz "$ROOT/work/cache_distfiles/" || true
if [ -f "$WORKSPACE/firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz" ]; then
    cp "$WORKSPACE/firmware-local/gta4l-firmware-T505XXS8CXG1.tar.gz" "$ROOT/sources/pmaports/device/downstream/firmware-samsung-gta4l/"
fi
if [ -f "$WORKSPACE/firmware-local/gta4l-sensor-firmware-T505XXS8CXG1.tar.gz" ]; then
    cp "$WORKSPACE/firmware-local/gta4l-sensor-firmware-T505XXS8CXG1.tar.gz" "$ROOT/sources/pmaports/device/downstream/firmware-sensors-gta4l/"
fi
exec bash "$WORKSPACE/tools/pmb.sh" "$@"
