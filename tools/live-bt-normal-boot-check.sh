#!/bin/sh
set -eu
echo '=== Kernel and boot identity ==='
uname -a
uname -v | grep -q '#9-postmarketOS'
cat /proc/sys/kernel/random/boot_id
echo '=== Bluetooth and device packages ==='
apk info -v | grep -E '^(bluetooth-gta4l|device-samsung-gta4l|linux-samsung-gta4l)-' | sort
echo '=== Automatic Bluetooth service ==='
rc-service gta4l-bluetooth status
rc-service bluetooth status
rc-update show default | grep -E 'gta4l-bluetooth|bluetooth'
cat /var/log/gta4l/bluetooth.log
grep -q BT_HCI_CONTROLLER_READY /var/log/gta4l/bluetooth.log
echo '=== Bluetooth networking and classic HID modules ==='
modprobe bnep
modprobe hidp
lsmod | grep -E 'bnep|hidp'
python3 - <<'PY'
import socket
for proto in (1, 4, 6):
    for _ in range(10):
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_RAW, proto)
        sock.close()
    print('BLUETOOTH_PROTOCOL_SOCKET_TEST_PASS', proto)
PY
echo '=== Controller and preserved pairing ==='
bluetoothctl show
bluetoothctl devices Paired
bluetoothctl devices Connected
echo '=== Core service regression ==='
rc-service lightdm status
rc-service gta4l-wlan status
rc-service gta4l-adsp status
rc-service modemmanager status
cat /proc/asound/cards
nmcli -f DEVICE,TYPE,STATE device status
echo '=== Recent Bluetooth kernel messages ==='
dmesg | grep -Ei 'Bluetooth|bnep|hidp|rapoo|BUG:|panic|Oops:' | tail -n 45
echo BT_AUTOMATIC_BOOT_CHECK_END
