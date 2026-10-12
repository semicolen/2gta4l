#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
cp "$WORKSPACE/diagnostics/gta4l-bootlog.c" "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-bootlog.c"
bash "$WORKSPACE/tools/pmb.sh" chroot --buildroot aarch64 --output stdout -- cc -Os -Wall -Wextra -Werror -static /tmp/gta4l-bootlog.c -o /tmp/gta4l-bootlog
mkdir -p "$ROOT/diagnostics"
cp "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-bootlog" "$ROOT/diagnostics/gta4l-bootlog"
file "$ROOT/diagnostics/gta4l-bootlog"
