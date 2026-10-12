#!/bin/sh
set -eu
dmesg | grep -E 'ttyHS|UART|bluetooth|Bluetooth|bt_power|bt_vreg|btpower' | tail -n 80
ls -l /lib/firmware/postmarketos/apbtfw11.tlv /lib/firmware/postmarketos/apnv11.bin
sha256sum /lib/firmware/postmarketos/apbtfw11.tlv /lib/firmware/postmarketos/apnv11.bin
find /sys/class/tty/ttyHS0/device -maxdepth 2 -type f -name '*clock*' -o -name '*baud*'
