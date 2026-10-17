#!/usr/bin/env bash
set -eu
ROOT=/home/ark/sm-t505-port
OUT="$ROOT/work/chroot_native/home/pmos/build/src/android_kernel_samsung_sm6115-381a5549ee66fa751f632ee0840f5631274209ee/out"
printf 'Local ARM64 object files: '
find "$OUT" -ignore_readdir_race -name '*.o' | wc -l
printf 'Built driver modules: '
find "$OUT" -ignore_readdir_race -name '*.ko' | wc -l
tail -18 "$ROOT/work/log.txt"
