#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
mkdir -p "$ROOT/downloads" "$ROOT/kernel"
ARCHIVE="$ROOT/downloads/linux-samsung-gta4l-381a5549ee66fa751f632ee0840f5631274209ee.tar.gz"
if [ ! -f "$ARCHIVE" ]; then
    curl -fL --retry 3 https://github.com/LineageOS/android_kernel_samsung_sm6115/archive/381a5549ee66fa751f632ee0840f5631274209ee.tar.gz -o "$ARCHIVE.part"
    mv "$ARCHIVE.part" "$ARCHIVE"
fi
EXPECTED=f39b6e8038903187d73ea0c0cb0c672862639c768c0f2be755b5557c6081b4198e9b4249682baf3522b3980e70ef5d389819d6b68bc84b415f4156485af0abf9
printf '%s  %s\n' "$EXPECTED" "$ARCHIVE" | sha512sum -c -
if [ ! -f "$ROOT/kernel/Makefile" ]; then
    tar -xzf "$ARCHIVE" --strip-components=1 -C "$ROOT/kernel"
fi
cd "$ROOT/kernel"
cat .gitmodules 2>/dev/null || true
if [ -f techpack/Makefile ]; then cat techpack/Makefile; fi
cat techpack/Kconfig
ls -la techpack
rg -n 'gta4l|audio|display|camera|wlan' .gitmodules build.config* arch/arm64/configs/gta4l* techpack/Kconfig || true
