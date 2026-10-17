#!/bin/sh
set -eu
KERNEL=/home/ark/sm-t505-port/kernel
echo '=== FSM sources ==='
rg --files "$KERNEL/techpack/audio" | rg '/fsm|fs16'
echo '=== Samsung audio DT paths ==='
rg --files "$KERNEL/arch/arm64/boot/dts" | rg 'gta4l.*(audio|sound)|gta4l|fsm' | head -n 40
echo '=== FSM firmware requests ==='
rg -n 'request_firmware|firmware_name|FSM_Scene|FSM.*Volume|fsm.*bin' "$KERNEL/techpack/audio" -g '*fsm*' -g '*fs16*' | head -n 100
