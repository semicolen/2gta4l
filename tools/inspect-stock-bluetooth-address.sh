#!/bin/sh
set -eu
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
echo '=== Read-only EFS Bluetooth directory ==='
debugfs -R 'ls /bluetooth' "$WORKSPACE/artifacts/backups/20261009-214946/sec_efs.img"
echo '=== Stock vendor Bluetooth library references ==='
mkdir -p "$ROOT/stock/vendor/inspect"
debugfs -R "dump /lib64/hw/android.hardware.bluetooth@1.0-impl-qti.so $ROOT/stock/vendor/inspect/bluetooth-qti.so" "$ROOT/stock/vendor/vendor.img"
strings "$ROOT/stock/vendor/inspect/bluetooth-qti.so" | rg 'bdaddr|bd_addr|bt_addr|/efs|apbtfw|apnv|apache|baud|sec_efs' | head -n 85
