#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
SOURCE="$ROOT/diagnostics/mesa-gpu-source"
mkdir -p "$SOURCE"
if [ ! -f "$SOURCE/mesa-26.2.4/src/gallium/drivers/zink/zink_screen.c" ]; then
    tar -xJf "$ROOT/work/cache_distfiles/mesa-26.2.4.tar.xz" -C "$SOURCE"
fi
SRC="$SOURCE/mesa-26.2.4"
echo '=== Zink mandatory extensions ==='
rg -n -C 5 'maintenance5|required|dev_major|fstat|GetImageSubresourceLayout' "$SRC/src/gallium/drivers/zink/zink_screen.c" | tail -n 180
echo '=== EGL software and Zink selection ==='
rg -n -C 5 'ForceSoftware|Options.Zink|LIBGL_KOPPER|kgsl|pseudo-drm' "$SRC/src/egl/main/egldisplay.c" "$SRC/src/egl/drivers/dri2/egl_dri2.c" "$SRC/src/gallium/frontends/dri/dri_screen.c" | head -n 240
echo '=== KGSL pseudo DRM and Gallium device initialization ==='
rg -n -C 4 'kgsl|LIBGL_KOPPER_DRI2|fd =|drm_fd' "$SRC/src/gallium/targets/dri" "$SRC/src/gallium/winsys/zink" "$SRC/src/loader/loader.c" | head -n 240
