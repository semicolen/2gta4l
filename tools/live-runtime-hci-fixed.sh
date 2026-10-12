stty -echo
printf '\nGTA4L_RUNTIME_BEGIN\n'
cat /proc/uptime
rc-service bluetooth status
rc-service modemmanager status
tail -85 /var/log/gta4l/staged-default-hci-fix.log
ip -br link
rfkill list
mmcli -L
ls -l /sys/class/bluetooth /sys/class/net /dev/subsys* /dev/wcnss* /dev/ttyHS* /dev/btpower
python3 - <<'GTA4L_PYTHON_END'
import fcntl
import os
import struct
fd = os.open('/dev/fb0', os.O_RDONLY)
v = bytearray(160)
fcntl.ioctl(fd, 0x4600, v, True)
print('FB x/y/bpp:', struct.unpack_from('II', v), struct.unpack_from('I', v, 24)[0])
for name, offset in [('red',32),('green',44),('blue',56),('transparency',68)]:
    print('FB field', name, struct.unpack_from('III', v, offset))
os.close(fd)
GTA4L_PYTHON_END
dmesg | grep -Ei 'wlan|icnss|wcnss|bluetooth|hci|qmi|remoteproc|subsys|firmware' | tail -70
printf '\nGTA4L_RUNTIME_END\n'
stty echo
