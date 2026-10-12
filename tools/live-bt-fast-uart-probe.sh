#!/bin/sh
set -eu
python3 /tmp/gta4l-upload/gta4l-bt-initialize.py --probe --baud 3000000
rfkill list
