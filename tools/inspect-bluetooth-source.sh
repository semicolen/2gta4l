#!/bin/sh
set -eu
ROOT=/home/pmos/sm-t505-port
KERNEL="$ROOT/kernel"
echo '=== Kernel QCA UART startup ==='
rg -n -C 7 'qca_setup|qca_power|WCN3990|qca_set_speed|qca_init' "$KERNEL/drivers/bluetooth/hci_qca.c" | tail -n 200
echo '=== Firmware mapping ==='
rg -n -C 5 'WCN3990|rampatch|nvm|fwname|firmware' "$KERNEL/drivers/bluetooth/btqca.c" | tail -n 150
echo '=== Downstream Bluetooth power controls ==='
rg -n 'BT_CMD|BT_SOC|ioctl|rfkill|power_setup|wcn399' "$KERNEL/drivers/bluetooth/btpower.c" | head -n 85
echo '=== Stock bluetooth filenames ==='
debugfs -R 'ls /firmware' "$ROOT/stock/vendor/vendor.img" 2>/dev/null | grep -Ei 'apbt|apnv|nvm|rampatch' || true
