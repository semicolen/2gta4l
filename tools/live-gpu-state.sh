stty -echo
printf '\nGTA4L_GPU_STATE_BEGIN\n'
uname -a
cat /proc/uptime
ps -eo pid,args | grep -E 'xfce4-session|xfwm4|Xorg'
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
if [ ! -f "$XAUTHORITY" ]; then XAUTHORITY=/var/run/lightdm/tablet/xauthority; export XAUTHORITY; fi
command -v glxinfo vulkaninfo eglinfo
glxinfo -B
ls -l /dev/dri /dev/kgsl* /usr/share/vulkan/icd.d /usr/lib/dri
apk --no-network info | grep -E 'mesa|vulkan|libdrm|freedreno'
for f in /sys/class/kgsl/kgsl-3d0/gpu_model /sys/class/kgsl/kgsl-3d0/gpuclk /sys/class/kgsl/kgsl-3d0/max_gpuclk /sys/class/kgsl/kgsl-3d0/gpubusy; do [ ! -f "$f" ] || { echo "$f"; cat "$f"; }; done
dmesg | grep -iE 'kgsl|adreno|a610|gpu' | tail -30
printf '\nGTA4L_GPU_STATE_END\n'
stty echo
