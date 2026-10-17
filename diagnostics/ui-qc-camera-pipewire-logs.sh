#!/bin/sh
set -eu
for camera in rear front; do
    echo "$camera"
    tail -n 35 "/run/gta4l-camera-pipewire-test/$camera.log"
done
ps -o pid,comm,stat -p "$(pidof gta4l-camera-pipewire | tr ' ' ',')" || true
timeout 15 qmicli -d qrtr://0 --loc-get-predicted-orbits-data-validity || true
