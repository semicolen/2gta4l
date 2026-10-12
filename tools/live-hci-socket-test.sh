if [ -t 0 ]; then stty -echo; fi
printf '\nGTA4L_HCI_TEST_BEGIN\n'
uname -a
printf '<6>GTA4L_TEST: HCI raw socket regression test\n' > /dev/kmsg
python3 - <<'GTA4L_PYTHON_END'
import platform
import socket
assert any(v in platform.version() for v in ['#4-postmarketOS', '#5-postmarketOS', '#6-postmarketOS', '#7-postmarketOS', '#8-postmarketOS'])
for i in range(10):
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, socket.BTPROTO_HCI)
    s.close()
print('PASS: created and closed 10 raw HCI sockets without the original kernel BUG')
GTA4L_PYTHON_END
printf '\nGTA4L_HCI_TEST_END\n'
if [ -t 0 ]; then stty echo; fi
