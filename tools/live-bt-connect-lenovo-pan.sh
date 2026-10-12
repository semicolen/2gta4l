#!/bin/sh
set -eu
modprobe bnep
python3 - <<'PY'
import re
import subprocess

def run(*args):
    return subprocess.check_output(args, text=True, timeout=8).strip()

peers = []
for line in run('bluetoothctl', 'devices', 'Paired').splitlines():
    parts = line.split(' ', 2)
    if len(parts) == 3 and parts[0] == 'Device' and parts[2].upper().replace('_', '-') == 'LENOVO-IDEAPAD1':
        assert re.fullmatch(r'(?:[0-9A-F]{2}:){5}[0-9A-F]{2}', parts[1])
        peers.append(parts[1])
assert len(peers) == 1, 'Expected one user-paired Lenovo laptop'
peer = peers[0]
info = run('bluetoothctl', 'info', peer)
assert 'Paired: yes' in info and '00001116-0000-1000-8000-00805f9b34fb' in info, 'Peer must advertise the NAP service'
name = 'gta4l-lenovo-pan'
names = run('nmcli', '-g', 'NAME', 'connection', 'show').splitlines()
if name in names:
    assert names.count(name) == 1
    saved = run('nmcli', '-g', 'bluetooth.bdaddr', 'connection', 'show', name)
    assert saved.upper() == peer, 'Existing PAN profile belongs to a different peer'
else:
    subprocess.run(['nmcli', 'connection', 'add', 'type', 'bluetooth', 'con-name', name,
                    'bluetooth.type', 'panu', 'bluetooth.bdaddr', peer,
                    'ipv4.method', 'auto', 'ipv4.route-metric', '700',
                    'ipv6.method', 'disabled', 'connection.autoconnect', 'no'], check=True, timeout=8)
print('LENOVO_PAN_PROFILE_VALIDATED', flush=True)
subprocess.run(['nmcli', '--wait', '22', 'connection', 'up', 'id', name], check=True, timeout=26)
PY
echo '=== Bluetooth network address ==='
ip -4 addr show bnep0
nmcli -f GENERAL,IP4 connection show gta4l-lenovo-pan
echo LENOVO_PAN_CONNECTION_ACTIVE
