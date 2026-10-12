#!/bin/sh
set -u
ls -l /etc/conf.d/polkit
cat /etc/conf.d/polkit
ls -l /usr/lib/polkit-1/polkitd
rc-service --debug polkit status 2>&1 | grep -E 'conf.d|command_user|command_args|output_log|error_log|polkitd|supervise' | tail -n 80
echo POLKIT_CONFIG_STATE_END
