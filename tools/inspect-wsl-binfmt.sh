#!/bin/sh
set -eu
ROOT=/home/pmos/sm-t505-port
echo '=== Binary emulation handlers ==='
ls -l /proc/sys/fs/binfmt_misc
for handler in /proc/sys/fs/binfmt_misc/*aarch64*; do
    [ ! -f "$handler" ] || cat "$handler"
done
command -v qemu-aarch64 || true
echo '=== Build-root executable ==='
file "$ROOT/work/chroot_buildroot_aarch64/bin/busybox"
echo '=== pmbootstrap handler management ==='
rg --files "$ROOT/sources/pmbootstrap/pmb" | rg 'binfmt|qemu'
rg -n 'binfmt|qemu.*register' "$ROOT/sources/pmbootstrap/pmb/chroot" | head -n 70
