if [ -t 0 ]; then stty -echo; fi
printf '\nGTA4L_RECOVERY_REBOOT_BEGIN\n'
rc-service lightdm stop
if grep -q ' /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf ' /proc/mounts; then
    umount /etc/X11/xorg.conf.d/90-gta4l-fbdev.conf
fi
python3 - <<'GTA4L_PYTHON_END'
import ctypes
import os
import platform
import time

assert os.geteuid() == 0
assert platform.machine() == 'aarch64'
os.sync()
print('Requesting vendor recovery reboot in two seconds', flush=True)
time.sleep(2)
# Linux asm-generic __NR_reboot, verified for this ARM64 kernel.
libc = ctypes.CDLL(None, use_errno=True)
ret = libc.syscall(ctypes.c_long(142), ctypes.c_ulong(0xfee1dead), ctypes.c_ulong(672274793), ctypes.c_ulong(0xa1b2c3d4), ctypes.c_char_p(b'recovery'))
if ret != 0:
    raise OSError(ctypes.get_errno(), 'Recovery reboot failed')
GTA4L_PYTHON_END
printf '\nGTA4L_RECOVERY_REBOOT_END\n'
