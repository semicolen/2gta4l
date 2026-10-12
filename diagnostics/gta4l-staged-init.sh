#!/bin/busybox ash
# One-boot diagnostic sysinit task; BusyBox remains PID 1.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umount /etc/inittab || exit 1
mkdir -p /run/gta4l-diagnostic
echo 'GTA4L_STAGE: diagnostic sysinit reached; OpenRC is paused' > /dev/kmsg
printf '\nSM-T505 staged startup: OpenRC paused; USB console port 2323\n'
telnetd -b 172.16.42.1:2323 -l /bin/sh
echo $$ > /run/gta4l-diagnostic/init.pid
# Keep the sysinit task alive while the host starts services individually.
while :; do
    sleep 3600
done
