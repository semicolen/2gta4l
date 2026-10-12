#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port/sources
rg -n 'deviceinfo_dtb|bootimg_dtb|generate_bootimg|ramdisk_offset|dtb_offset' "$ROOT/pmaports/main/postmarketos-mkinitfs" "$ROOT/pmaports/main/devicepkg-dev" "$ROOT/pmaports/device/downstream" | head -100 || true
find "$ROOT/pmbootstrap/pmb/config" -maxdepth 1 -type f
rg -n 'ConfigParser|pmbootstrap|save|load' "$ROOT/pmbootstrap/pmb/config/user.py" || true
cat "$ROOT/orangefox/tools/extract_vendor.py"
cat "$ROOT/pmaports/pmaports.cfg"
cat "$ROOT/pmaports/main/devicepkg-dev/downstreamkernel_prepare.sh"
