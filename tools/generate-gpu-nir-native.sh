#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
SRC="$ROOT/work/chroot_buildroot_aarch64/home/pmos/build/src/mesa-26.2.4"
OUT="$ROOT/diagnostics/nir_opt_algebraic.native.c"
# Compare pure Python code generation on the WSL host with ARM64 emulation.
# The live Ninja output remains untouched.
export PYTHONPATH="$ROOT/work/chroot_buildroot_aarch64/usr/lib/python3.14/site-packages"
time timeout 60 python3 "$SRC/src/compiler/nir/nir_opt_algebraic.py" --out "$OUT"
sha256sum "$OUT"
