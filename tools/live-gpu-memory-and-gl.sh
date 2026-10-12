#!/bin/sh
set -u
echo '=== GPU memory devices ==='
ls -l /dev/ion /dev/dma_heap/* 2>/dev/null
udevadm info --query=property --name=/dev/ion
echo '=== Current GL renderer ==='
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
glxinfo -B
echo '=== Firmware and WLAN subsystem status ==='
ls /sys/bus/msm_subsys/devices/* 2>/dev/null
echo GPU_MEMORY_GL_END
