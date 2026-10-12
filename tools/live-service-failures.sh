#!/bin/sh
set -u
echo '=== Startup errors ==='
grep -n -B 5 -A 9 -Ei 'fail|error|sshd|polkit|sysusers|ModemManager' /var/log/rc.log | tail -n 240
echo '=== Accounts ==='
getent passwd polkitd
getent passwd sshd
getent group video
id tablet
echo '=== Runtime directories and SSH config ==='
ls -ld /run /run/sshd /var/run
ls -l /run/sshd* /etc/ssh/sshd_config
grep -Ev '^#|^$' /etc/ssh/sshd_config
echo '=== Time and logging ==='
ls -l /var/log
command -v logread logbookctl journalctl
echo '=== Modem manager ==='
mmcli -L
mmcli --set-logging=DEBUG
qrtr-lookup
echo SERVICE_FAILURES_END
