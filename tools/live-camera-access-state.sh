#!/bin/sh
set -eu
id tablet
getent group video
printf '=== Existing graphics session ===\n'
pgrep -a -u tablet -x xfce4-session
printf '=== Camera development processes ===\n'
ps -eo pid,user,comm | grep -E 'camera-hal|gta4l-camera' || true
printf 'CAMERA_ACCESS_STATE_END\n'
