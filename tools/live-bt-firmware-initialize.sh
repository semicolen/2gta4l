#!/bin/sh
set -eu
python3 /tmp/gta4l-upload/gta4l-bt-initialize.py --initialize --baud 3000000
echo BT_FIRMWARE_INITIALIZATION_COMPLETE
