#!/bin/sh
# Apply only to the explicitly selected Adreno session; preserve the fallback.
if [ "${GTA4L_ZINK_KGSL:-0}" = 1 ]; then
    unset LIBGL_ALWAYS_SOFTWARE D3D_ALWAYS_SOFTWARE QT_QUICK_BACKEND
    export VK_DRIVER_FILES=/usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
    export GALLIUM_DRIVER=zink MESA_LOADER_DRIVER_OVERRIDE=zink GTA4L_ZINK_KGSL=1
    export LIBGL_KOPPER_DISABLE=true
    export LIBGL_DRIVERS_PATH=/usr/lib/gta4l-zink/lib/dri
    export LD_LIBRARY_PATH=/usr/lib/gta4l-zink/lib
fi
