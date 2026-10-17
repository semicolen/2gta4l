#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
bash "$WS/tools/pmb.sh" chroot -b aarch64 --output stdout -- apk add pipewire-dev wayland-dev
cp "$WS/port/camera-pipewire-gta4l/gta4l-camera-pipewire.c" "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-camera-pipewire.c"
bash "$WS/tools/pmb.sh" chroot -b aarch64 --output stdout -- /bin/sh -c 'cc -O2 -Wall -Wextra -Werror -pthread /tmp/gta4l-camera-pipewire.c -o /tmp/gta4l-camera-pipewire $(pkg-config --cflags --libs libpipewire-0.3 wayland-client)'
install -m755 "$ROOT/work/chroot_buildroot_aarch64/tmp/gta4l-camera-pipewire" "$WS/artifacts/gta4l-camera-pipewire"
sha256sum "$WS/artifacts/gta4l-camera-pipewire"
echo CAMERA_PIPEWIRE_PROTOTYPE_BUILT_LOCALLY_IN_WSL
