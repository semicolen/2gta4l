#!/bin/sh
set -eu
libinput quirks list /dev/input/event1
libinput list-devices
