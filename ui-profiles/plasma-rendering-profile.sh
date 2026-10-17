# Respect the explicit Adreno session selected by gta4l-zink-run.
if [ "${GTA4L_ZINK_KGSL:-0}" != 1 ]; then
#!/bin/sh
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export QT_QUICK_BACKEND=software

fi
