#!/bin/sh
set -eu
export XDG_RUNTIME_DIR=/run/user/10000
pacmd set-log-level 4
pacmd set-log-target file:/home/tablet/.cache/gta4l-pulse-debug.log
echo PULSE_DEBUG_CAPTURE_READY
