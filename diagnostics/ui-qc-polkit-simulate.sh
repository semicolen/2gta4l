#!/bin/sh
set -eu
apk add --no-network --simulate /tmp/gta4l-upload/polkit-elogind-127-r3.apk \
    /tmp/gta4l-upload/polkit-elogind-libs-127-r3.apk gnome-keyring gcr
printf '\nPOLKIT_REPLACEMENT_SIMULATION_END\n'
