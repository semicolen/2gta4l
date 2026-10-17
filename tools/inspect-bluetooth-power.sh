#!/bin/sh
set -eu
KERNEL=/home/ark/sm-t505-port/kernel
echo '=== UART power pulse ==='
sed -n '1010,1140p' "$KERNEL/drivers/bluetooth/hci_qca.c"
echo '=== Version query ==='
sed -n '28,114p' "$KERNEL/drivers/bluetooth/btqca.c"
echo '=== UART flow control ==='
rg -n -A 62 'void hci_uart_set_flow_control' "$KERNEL/drivers/bluetooth/hci_ldisc.c"
echo '=== Vendor power driver paths ==='
rg --files "$KERNEL/drivers" | rg 'bt[_-]?power'
