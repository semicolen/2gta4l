#!/bin/sh
set -eu
[ -x /usr/bin/tqftpserv-gta4l ]
grep -q gta4l-tqftpserv /etc/init.d/gta4l-modem
/usr/libexec/rc/bin/rc-depend -u
rc-service gta4l-tqftpserv start
rc-service gta4l-adsp start
rc-service gta4l-modem start
rc-service gta4l-ipa start
sleep 5
head -c 28934160 /dev/mmcblk0p69 | sha256sum
echo DOWNSTREAM_TQFTP_START_END
