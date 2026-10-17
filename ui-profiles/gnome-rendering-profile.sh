#!/bin/sh
# Respect the explicit Adreno session; keep GDM and the fallback on software.
if [ "${GTA4L_ZINK_KGSL:-0}" != 1 ]; then
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export QT_QUICK_BACKEND=software
fi
