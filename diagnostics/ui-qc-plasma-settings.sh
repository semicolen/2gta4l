#!/bin/sh
set -eu
printf 'PLASMA_SAVED_INPUT_SETTINGS\n'
cat /home/tablet/.config/kcminputrc
printf '\nPLASMA_WAYLAND_SETTINGS\n'
cat /home/tablet/.config/kwinrc
printf '\nSENSOR_AVAILABILITY\n'
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
    --method org.freedesktop.DBus.Properties.GetAll net.hadess.SensorProxy
