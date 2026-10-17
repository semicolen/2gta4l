#!/bin/sh
set -eu
ROOT=/home/ark/sm-t505-port
NATIVE="$ROOT/work/chroot_native"
cp "$ROOT/stock/vendor/inspect/bluetooth-qti.so" "$NATIVE/tmp/gta4l-bluetooth-qti.so"
chroot "$NATIVE" /usr/bin/aarch64-alpine-linux-musl-objdump -d -C --start-address=0x5a47c --stop-address=0x5aa4c /tmp/gta4l-bluetooth-qti.so > "$ROOT/stock/vendor/inspect/bt-stock-baud.disassembly"
chroot "$NATIVE" /usr/bin/aarch64-alpine-linux-musl-objdump -d -C --start-address=0x60564 --stop-address=0x60a24 /tmp/gta4l-bluetooth-qti.so > "$ROOT/stock/vendor/inspect/bt-stock-segment.disassembly"
cat "$ROOT/stock/vendor/inspect/bt-stock-baud.disassembly"
cat "$ROOT/stock/vendor/inspect/bt-stock-segment.disassembly"
