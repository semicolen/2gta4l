#!/bin/sh
set -eu
rc-service polkit stop || true
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -f -s 160 \
    -e trace=openat,close,unlink,unlinkat,execve,setuid,setgid,setgroups,setreuid,setregid,capset,prctl,wait4,waitid \
    -o /tmp/gta4l-trace/polkit-launch.log rc-service polkit start &
tracer=$!
sleep 3
kill -INT "$tracer" 2>/dev/null || true
sleep 1
echo '=== Launch trace ==='
grep -E 'supervise-polkit|polkit.log|polkitd|setuid|setgid|setreuid|setregid|EACCES|ENOENT|EINVAL' /tmp/gta4l-trace/polkit-launch.log | tail -n 140
echo '=== Launch result ==='
pidof polkitd || true
rc-service polkit status
echo POLKIT_LAUNCH_TRACE_END
