#!/bin/sh
set -eu
printf '%s\n' 'b3438f008b750a0868b0065dea3ba0aa159251375d706af35a21b21f9813ed16  /tmp/gta4l-upload/78-mm-gta4l.rules' | sha256sum -c -
install -m644 /tmp/gta4l-upload/78-mm-gta4l.rules /etc/udev/rules.d/78-mm-gta4l.rules
udevadm control --reload-rules
udevadm trigger --action=change /sys/class/net/rmnet_ipa0
udevadm settle --timeout=5
udevadm info --query=property --path=/sys/class/net/rmnet_ipa0
mmcli -L
tail -n 65 /var/log/gta4l/modemmanager-debug.log
echo RMNET_RULE_TEST_END
