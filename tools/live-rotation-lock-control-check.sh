#!/bin/sh
set -eu
gta4l-rotate --lock
sleep 2
gta4l-rotate --status
gta4l-rotate --unlock
sleep 2
gta4l-rotate --status
tail -n 6 /home/tablet/.cache/gta4l-rotation/rotation.log
echo ROTATION_LOCK_CONTROL_CHECK_END
