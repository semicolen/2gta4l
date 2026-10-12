#!/bin/sh
set -eu
KERNEL=/home/pmos/sm-t505-port/kernel
CODEC="$KERNEL/techpack/audio/asoc/codecs/foursemi"
sed -n '1,280p' "$CODEC/fsm_codec.c"
rg -n 'fw_name|preset_name|fs1801|fsm_speaker_on|fsm_speaker_off|fsm_init|dev_count' "$CODEC/fsm_core.c" "$CODEC/fsm_i2c.c" "$CODEC/fsm_public.h" | head -n 80
rg -n -C 3 'fsm|fs1801|pri-mi2s|pri_mi2s' "$KERNEL/arch/arm64/boot/dts/vendor/qcom/bengal-audio.dtsi" "$KERNEL/arch/arm64/boot/dts/vendor/qcom/bengal-qrd.dtsi" | head -n 140
