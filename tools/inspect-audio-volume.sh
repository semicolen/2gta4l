#!/bin/sh
set -eu
KERNEL=/home/pmos/sm-t505-port/kernel
rg -n -C 5 '8192|playback_volume|Playback.*Volume|TLV_DB' "$KERNEL/techpack/audio/asoc/msm-pcm-q6-v2.c" | head -n 170
