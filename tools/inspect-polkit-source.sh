#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
SRC="$ROOT/sources/polkit-inspect"
mkdir -p "$SRC"
if [ ! -f "$SRC/polkit-127.tar.gz" ]; then
    curl --fail --location --retry 2 'https://github.com/polkit-org/polkit/archive/refs/tags/127.tar.gz' -o "$SRC/polkit-127.tar.gz"
fi
sha512sum "$SRC/polkit-127.tar.gz"
if [ ! -d "$SRC/polkit-127" ]; then tar -xzf "$SRC/polkit-127.tar.gz" -C "$SRC"; fi
rg -n 'dumpable|setuid|setresuid|drop.*privilege|setgid' "$SRC/polkit-127/src" | head -n 70
curl --fail --location 'https://raw.githubusercontent.com/alpinelinux/aports/master/main/polkit/APKBUILD' -o "$SRC/alpine-APKBUILD"
cat "$SRC/alpine-APKBUILD"
