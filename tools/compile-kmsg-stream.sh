#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/pmos/sm-t505-port
WORKSPACE='/mnt/c/postmarketOS-gta4l'
cp "$WORKSPACE/diagnostics/gta4l-kmsg-stream.c" "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-kmsg-stream.c"
bash "$WORKSPACE/tools/pmb.sh" chroot --buildroot aarch64 --output stdout -- cc -Os -Wall -Wextra -Werror -static /tmp/gta4l-kmsg-stream.c -o /tmp/gta4l-kmsg-stream
cp "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-kmsg-stream" "$ROOT/diagnostics/gta4l-kmsg-stream"
cp "$ROOT/diagnostics/gta4l-kmsg-stream" "$WORKSPACE/artifacts/gta4l-kmsg-stream"
file "$ROOT/diagnostics/gta4l-kmsg-stream"
