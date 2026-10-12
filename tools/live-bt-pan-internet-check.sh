#!/bin/sh
set -eu
echo '=== PAN link and DHCP ==='
ip -4 addr show bnep0
ip -4 route show dev bnep0
python3 - <<'PY'
from pathlib import Path
import ipaddress
import json
import secrets
import socket
import ssl
import struct
import subprocess

device = 'bnep0'
domain = 'example.org'
profile = 'gta4l-lenovo-pan'
state = subprocess.check_output(['nmcli', '-g', 'GENERAL.STATE', 'connection', 'show', profile], text=True)
assert state.strip() == 'activated', 'Bluetooth PAN must be connected'
assert (Path('/sys/class/net')/device/'carrier').read_text().strip() == '1'
dns = subprocess.check_output(['nmcli', '-g', 'IP4.DNS', 'connection', 'show', profile], text=True).splitlines()
servers = [str(ipaddress.IPv4Address(value.strip())) for value in dns if value.strip()]
assert servers, 'PAN DHCP provided no IPv4 DNS server'
def counters():
    return {name: int((Path('/sys/class/net')/device/'statistics'/name).read_text())
            for name in ['rx_bytes', 'tx_bytes']}
before = counters()
identifier = secrets.randbelow(65536)
question = b''.join(bytes([len(part)])+part.encode('ascii') for part in domain.split('.'))+b'\0'+struct.pack('!HH', 1, 1)
query = struct.pack('!6H', identifier, 0x100, 1, 0, 0, 0)+question
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, device.encode()+b'\0')
    sock.settimeout(5)
    sock.connect((servers[0], 53))
    sock.send(query)
    answer = sock.recv(4096)
assert len(answer) >= 12
rid, flags, qd, an, ns, ar = struct.unpack_from('!6H', answer)
assert rid == identifier and flags & 0x8000 and flags & 15 == 0 and not flags & 0x200
assert qd == 1 and an > 0 and answer[12:12+len(question)] == question
def skip_name(offset):
    for _ in range(128):
        assert offset < len(answer)
        size = answer[offset]
        offset += 1
        if size == 0:
            return offset
        if size & 0xc0 == 0xc0:
            assert offset < len(answer)
            return offset+1
        assert size < 64 and offset+size <= len(answer)
        offset += size
    raise ValueError('DNS name exceeds bounds')
offset = 12+len(question)
addresses = []
for _ in range(an):
    offset = skip_name(offset)
    assert offset+10 <= len(answer)
    kind, cls, ttl, size = struct.unpack_from('!HHIH', answer, offset)
    offset += 10
    assert offset+size <= len(answer)
    if kind == 1 and cls == 1 and size == 4:
        addresses.append(socket.inet_ntoa(answer[offset:offset+size]))
    offset += size
assert addresses, 'No IPv4 DNS answer over PAN'
context = ssl.create_default_context()
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp:
    tcp.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, device.encode()+b'\0')
    tcp.settimeout(10)
    tcp.connect((addresses[0], 443))
    with context.wrap_socket(tcp, server_hostname=domain) as https:
        https.sendall(('GET / HTTP/1.1\r\nHost: '+domain+'\r\nConnection: close\r\n\r\n').encode())
        response = https.recv(4096)
        status = response.split(b'\r\n', 1)[0].decode('ascii')
        assert status.startswith('HTTP/1.1 200') or status.startswith('HTTP/1.0 200'), status
after = counters()
delta = {name: after[name]-before[name] for name in before}
assert all(value > 0 for value in delta.values())
print(json.dumps({'interface': device, 'dns_bound_to_pan': True,
                  'https_bound_to_pan': True, 'tls_certificate_verified': True,
                  'http_status': status, 'traffic_delta_bytes': delta}, sort_keys=True))
print('BLUETOOTH_PAN_INTERNET_VERIFIED')
PY
