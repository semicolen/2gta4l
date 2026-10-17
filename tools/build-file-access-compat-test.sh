#!/bin/sh
set -eu
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
ROOT=/home/ark/sm-t505-port/work/chroot_native
target=/tmp/gta4l-faccessat2-arm32-test
cp "$WS/tools/faccessat2-arm32-test.S" "$ROOT$target.S"
chroot "$ROOT" clang --target=armv7-linux-musleabi -fuse-ld=lld \
    -nostdlib -static -Wl,--build-id=none -Wl,-e,_start \
    "$target.S" -o "$target"
cp "$ROOT$target" "$WS/artifacts/file-access-kernel-fix/faccessat2-arm32-test"
file "$WS/artifacts/file-access-kernel-fix/faccessat2-arm32-test"
