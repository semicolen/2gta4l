#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
timeout 20 monitor-sensor --accel
