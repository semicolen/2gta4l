#!/bin/sh
set -u
echo '=== Ordinary user self-access ==='
su tablet -c 'id; ls -ld /proc/self/fdinfo; cat /proc/self/fdinfo/0'
echo '=== Polkit launch settings ==='
rc-service --debug polkit restart 2>&1 | grep -E 'command_user|output_log|error_log|supervise-daemon .*start|--user|--stdout|--stderr|error|denied' | tail -n 80
echo '=== Restarted service descriptors ==='
pid=$(pidof polkitd)
ls -ld "/proc/$pid/fdinfo"
ls -l "/proc/$pid/fd/1" "/proc/$pid/fd/2"
echo PROC_SELF_PERMISSIONS_END
