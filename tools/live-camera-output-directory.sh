#!/bin/sh
set -eu
ROOT=/opt/gta4l-camera-dev/r0
ls -ld "$ROOT/data" "$ROOT/data/vendor" "$ROOT/data/vendor/camera" "$ROOT/data/misc/camera" 2>/dev/null || true
mkdir -p "$ROOT/data/vendor/camera" "$ROOT/data/misc/camera" "$ROOT/data/vendor/camera/cache"
chmod 700 "$ROOT/data/vendor/camera" "$ROOT/data/misc/camera" "$ROOT/data/vendor/camera/cache"
printf 'CAMERA_PRIVATE_OUTPUT_READY\n'
