#!/bin/sh
set -u
echo '=== Tablet clock and time services ==='
date -u
ls -l /dev/rtc* /sys/class/rtc 2>/dev/null
for service in chronyd ntpd openntpd; do
    if [ -f "/etc/init.d/$service" ]; then rc-service "$service" status; fi
done
echo '=== HTTPS with certificate validation through Wi-Fi ==='
python3 - <<'PY'
import socket, ssl, subprocess
status = subprocess.check_output(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device'], text=True)
active = [row.split(':')[0] for row in status.splitlines() if row.endswith(':wifi:connected')]
assert active and active[0] in ('wlan0', 'swlan0')
interface = active[0]
host = 'postmarketos.org'
context = ssl.create_default_context()
address = socket.getaddrinfo(host, 443, socket.AF_INET, socket.SOCK_STREAM)[0][4]
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.settimeout(8)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, interface.encode() + b'\0')
    sock.connect(address)
    with context.wrap_socket(sock, server_hostname=host) as tls:
        tls.sendall(b'HEAD / HTTP/1.1\r\nHost: postmarketos.org\r\nConnection: close\r\n\r\n')
        response = tls.recv(2048).decode('latin1')
        first_line = response.split('\r\n', 1)[0]
        print('Interface:', interface)
        print('TLS:', tls.version(), 'certificate verification enabled')
        print('HTTP:', first_line)
        assert first_line.startswith('HTTP/') and first_line.split()[1] in ('200', '301', '302', '308')
        print('WIFI_HTTPS_VERIFIED')
PY
echo "wifi_https_python_status=$?"
echo WIFI_HTTPS_CLOCK_END
