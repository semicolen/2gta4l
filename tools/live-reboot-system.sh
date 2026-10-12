#!/bin/sh
set -eu
uname -a
echo 'Rebooting normally to validate automatic service startup.'
sync
/sbin/reboot
