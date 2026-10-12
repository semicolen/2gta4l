#!/usr/bin/env bash
set -eu
ROOT=/home/pmos/sm-t505-port
mkdir -p "$ROOT/sources/recovery-installer"
if [ ! -f "$ROOT/sources/recovery-installer/update-binary" ]; then
    curl -fL --retry 3 https://gitlab.com/postmarketos/postmarketos-android-recovery-installer/-/archive/1.0.7/postmarketos-android-recovery-installer-1.0.7.tar.gz -o "$ROOT/downloads/recovery-installer.tar.gz"
    tar -xzf "$ROOT/downloads/recovery-installer.tar.gz" --strip-components=1 -C "$ROOT/sources/recovery-installer"
fi
cat "$ROOT/sources/recovery-installer/update-binary"
rg -n 'INSTALL_PARTITION|SYSTEM_PARTLABEL|KERNEL_PARTLABEL|INITFS|FLASH_KERNEL|format|mkfs|find.*part' "$ROOT/sources/recovery-installer" | head -110
