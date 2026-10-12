#!/bin/sh
set -u
echo '=== Kernel and boot ==='
date -u
uptime
uname -a
cat /proc/cmdline
echo '=== Services ==='
rc-status -a
ps -eo pid,ppid,comm,args | grep -E 'sshd|Xorg|lightdm|xfce|ModemManager|NetworkManager|qrtr|rmtfs|pd-mapper|tqftp|gta4l' | grep -v grep
echo '=== USB and calibration ==='
ip -4 addr show usb0
cat /etc/udev/rules.d/98-touchscreen-cal.rules
echo '=== GPU devices ==='
ls -l /dev/kgsl-3d0 /dev/dri/* 2>/dev/null || true
cat /sys/class/kgsl/kgsl-3d0/gpu_model
echo '=== Boot service log ==='
tail -n 100 /var/log/rc.log
echo '=== Recent kernel log ==='
dmesg | tail -n 80
echo NORMAL_BOOT_STATE_END
